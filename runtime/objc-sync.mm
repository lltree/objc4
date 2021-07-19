/*
 * Copyright (c) 1999-2007 Apple Inc.  All Rights Reserved.
 *
 * @APPLE_LICENSE_HEADER_START@
 *
 * This file contains Original Code and/or Modifications of Original Code
 * as defined in and that are subject to the Apple Public Source License
 * Version 2.0 (the 'License'). You may not use this file except in
 * compliance with the License. Please obtain a copy of the License at
 * http://www.opensource.apple.com/apsl/ and read it before using this
 * file.
 *
 * The Original Code and all software distributed under the License are
 * distributed on an 'AS IS' basis, WITHOUT WARRANTY OF ANY KIND, EITHER
 * EXPRESS OR IMPLIED, AND APPLE HEREBY DISCLAIMS ALL SUCH WARRANTIES,
 * INCLUDING WITHOUT LIMITATION, ANY WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE, QUIET ENJOYMENT OR NON-INFRINGEMENT.
 * Please see the License for the specific language governing rights and
 * limitations under the License.
 *
 * @APPLE_LICENSE_HEADER_END@
 */

#include "objc-private.h"
#include "objc-sync.h"

//
// Allocate a lock only when needed.  Since few locks are needed at any point
// in time, keep them on a single list.
//

/*----------
SyncData中的recursive_mutex_t最终是recursive_mutex_tt类型,
recursive_mutex_tt内部有个pthread_mutex_t的锁,
这个锁初始化为一个递归锁 PTHREAD_RECURSIVE_MUTEX_INITIALIZER
----------*/
//https://blog.csdn.net/u014600626/article/details/107915866
// 是个链表结构
//alignas(CacheLineSize) 对齐方法
typedef struct alignas(CacheLineSize) SyncData {
    struct SyncData *nextData; //指向下一个SyncData的指针
    DisguisedPtr<objc_object> object; //就是我们传入的那个对象
    int32_t threadCount;  // number of THREADS using this block threadCount 就是递归锁在同一线程的加锁次数 当threadCount==0 就表明了这个 SyncData 实例可以被其他线程获得了。
    recursive_mutex_t mutex; //内部是一个递归锁
} SyncData;

typedef struct {
    SyncData *data;
    unsigned int lockCount;  // number of times THIS THREAD locked this block
} SyncCacheItem;

typedef struct SyncCache {
    unsigned int allocated;
    unsigned int used;
    SyncCacheItem list[0];
} SyncCache;

/*
  Fast cache: two fixed pthread keys store a single SyncCacheItem.
  This avoids malloc of the SyncCache for threads that only synchronize
  a single object at a time.
  SYNC_DATA_DIRECT_KEY  == SyncCacheItem.data
  SYNC_COUNT_DIRECT_KEY == SyncCacheItem.lockCount
 */
/*
 你可以把 SyncData 当做是链表中的节点。每个 SyncList 结构体都有个指向 SyncData 节点链表头部的指针，也有一个用于防止多个线程对此列表做并发修改的锁。
 */
struct SyncList {
    SyncData *data;
    spinlock_t lock;

    constexpr SyncList() : data(nil), lock(fork_unsafe_lock) {
    }
};

// Use multiple parallel lists to decrease contention among unrelated objects.

/*
 声明 - 一个 SyncList 结构体数组，大小为16。通过定义的一个哈希算法将传入对象映射到数组上的一个下标。值得注意的是这个哈希算法设计的很巧妙，是将对象指针在内存的地址转化为无符号整型并右移五位，再跟 0xF 做按位与运算，这样结果不会超出数组大小。 LOCK_FOR_OBJ(obj) 和 LIST_FOR_OBJ(obj) 这俩宏就更好理解了，先是哈希出对象的数组下标，然后取出数组对应元素的 lock 或 data。一切都是这么顺理成章哈。
 */
#define LOCK_FOR_OBJ(obj) sDataLists[obj].lock
#define LIST_FOR_OBJ(obj) sDataLists[obj].data
static StripedMap<SyncList> sDataLists;//HashMap 16个槽位

enum usage {
    ACQUIRE, RELEASE, CHECK
};

static SyncCache * fetch_cache(bool create) {
    _objc_pthread_data *data;

    data = _objc_fetch_pthread_data(create);

    if (!data) {
        return NULL;
    }

    if (!data->syncCache) {
        if (!create) {
            return NULL;
        }
        else {
            int count = 4;
            data->syncCache = (SyncCache *)
                calloc(1, sizeof(SyncCache) + count * sizeof(SyncCacheItem));
            data->syncCache->allocated = count;
        }
    }

    // Make sure there's at least one open slot in the list.
    if (data->syncCache->allocated == data->syncCache->used) {
        data->syncCache->allocated *= 2;
        data->syncCache = (SyncCache *)
            realloc(data->syncCache, sizeof(SyncCache)
                    + data->syncCache->allocated * sizeof(SyncCacheItem));
    }

    return data->syncCache;
}

void _destroySyncCache(struct SyncCache *cache) {
    if (cache) {
        free(cache);
    }
}

static SyncData * id2data(id object, enum usage why) {
    /*
     LOCK_FOR_OBJ(obj) 和 LIST_FOR_OBJ(obj) 这俩宏就更好理解了，先是哈希出对象的数组下标，然后取出数组对应元素的 lock 或 data。
     */
    spinlock_t *lockp = &LOCK_FOR_OBJ(object);//
    SyncData **listp = &LIST_FOR_OBJ(object);
    SyncData *result = NULL;

#if SUPPORT_DIRECT_THREAD_KEYS //第一种通过线程的暂存缓存
    // Check per-thread single-entry fast cache for matching object
    bool fastCacheOccupied = NO;
    //THREAD_KEYS
    //线程局部缓存TLS
    //先从 线程局部缓存TLS 中找，找到
    // SYNC_DATA_DIRECT_KEY 是线程key  DATA KEY
    SyncData *data = (SyncData *)tls_get_direct(SYNC_DATA_DIRECT_KEY);

    if (data) {
        fastCacheOccupied = YES;

        //如果找到的SyncData 中的object 和当前目标object一致
        if (data->object == object) {
            // Found a match in fast cache.
            uintptr_t lockCount;

            result = data;
            //COUNT KEY
            lockCount = (uintptr_t)tls_get_direct(SYNC_COUNT_DIRECT_KEY);

            if (result->threadCount <= 0  ||  lockCount <= 0) {
                _objc_fatal("id2data fastcache is buggy");
            }

            switch (why) {
                case ACQUIRE:
                { //acquire 获取操作
                    lockCount++; //被锁了多少次
                    //设置lockCount++
                    tls_set_direct(SYNC_COUNT_DIRECT_KEY, (void *)lockCount);
                    break;
                }

                case RELEASE:
                    lockCount--;
                    tls_set_direct(SYNC_COUNT_DIRECT_KEY, (void *)lockCount);

                    if (lockCount == 0) { //当锁的次数变为0 的时候，
                        // remove from fast cache
                        tls_set_direct(SYNC_DATA_DIRECT_KEY, NULL);
                        // atomic because may collide with concurrent ACQUIRE
                        OSAtomicDecrement32Barrier(&result->threadCount);
                    }

                    break;

                case CHECK:
                    // do nothing
                    break;
            }

            return result;
        }
    }

#endif

    // 第二种：从本地的缓存
    // 线程缓存中没找到 则从
    // Check per-thread cache of already-owned locks for matching object
    SyncCache *cache = fetch_cache(NO);

    if (cache) {
        unsigned int i;

        for (i = 0; i < cache->used; i++) {
            SyncCacheItem *item = &cache->list[i];

            if (item->data->object != object) {
                continue;
            }

            // Found a match.
            result = item->data;

            if (result->threadCount <= 0  ||  item->lockCount <= 0) {
                _objc_fatal("id2data cache is buggy");
            }

            switch (why) {
                case ACQUIRE:
                    item->lockCount++;
                    break;

                case RELEASE:
                    item->lockCount--;

                    if (item->lockCount == 0) {
                        // remove from per-thread cache
                        cache->list[i] = cache->list[--cache->used];
                        // atomic because may collide with concurrent ACQUIRE
                        OSAtomicDecrement32Barrier(&result->threadCount);
                    }

                    break;

                case CHECK:
                    // do nothing
                    break;
            }

            return result;
        }
    }

    // Thread cache didn't find anything.
    // Walk in-use list looking for matching object
    // Spinlock prevents multiple threads from creating multiple
    // locks for the same new object.
    // We could keep the nodes in some hash table if we find that there are
    // more than 20 or so distinct locks active, but we don't do that now.

    //第一次进来 缓存都不会走，直接从这里分析
    lockp->lock();

    {
        SyncData *p;
        SyncData *firstUnused = NULL;

        for (p = *listp; p != NULL; p = p->nextData) {
            if (p->object == object) {
                result = p;
                // atomic because may collide with concurrent RELEASE
                OSAtomicIncrement32Barrier(&result->threadCount);
                goto done;
            }

            if ( (firstUnused == NULL) && (p->threadCount == 0) ) {
                firstUnused = p;
            }
        }

        // no SyncData currently associated with object
        if ( (why == RELEASE) || (why == CHECK) ) {
            goto done;
        }

        // an unused one was found, use it
        if (firstUnused != NULL) { //第一次进来  会创建这个
            result = firstUnused;
            result->object = (objc_object *)object;
            result->threadCount = 1;
            goto done;
        }
    }

    // Allocate a new SyncData and add to list.
    // XXX allocating memory with a global lock held is bad practice,
    // might be worth releasing the lock, allocating, and searching again.
    // But since we never free these guys we won't be stuck in allocation very often.
    posix_memalign((void **)&result, alignof(SyncData), sizeof(SyncData));
    result->object = (objc_object *)object;
    result->threadCount = 1;
    new(&result->mutex) recursive_mutex_t(fork_unsafe_lock);
    result->nextData = *listp;
    *listp = result;

 done:
    lockp->unlock();

    if (result) {
        // Only new ACQUIRE should get here.
        // All RELEASE and CHECK and recursive ACQUIRE are
        // handled by the per-thread caches above.
        if (why == RELEASE) {
            // Probably some thread is incorrectly exiting
            // while the object is held by another thread.
            return nil;
        }

        if (why != ACQUIRE) {
            _objc_fatal("id2data is buggy");
        }

        if (result->object != object) {
            _objc_fatal("id2data is buggy");
        }

#if SUPPORT_DIRECT_THREAD_KEYS

        if (!fastCacheOccupied) { //第一次进来用 DATA KEY COUNT KEY kvc设置值
            // Save in fast thread cache
            tls_set_direct(SYNC_DATA_DIRECT_KEY, result); //存到线程缓存中
            tls_set_direct(SYNC_COUNT_DIRECT_KEY, (void *)1);
        }
        else
#endif
        {
            // Save in thread cache
            if (!cache) {
                cache = fetch_cache(YES);//对线程绑定了吗 ？进去看下
            }

            cache->list[cache->used].data = result;
            cache->list[cache->used].lockCount = 1;
            cache->used++;
        }
    }

    return result;
}

BREAKPOINT_FUNCTION(
    void objc_sync_nil(void)
    );

// Begin synchronizing on 'obj'.
// Allocates recursive mutex associated with 'obj' if needed.
// Returns OBJC_SYNC_SUCCESS once lock is acquired.

#pragma mark - @synchronized入口 obj 是一个token
int objc_sync_enter(id obj) {
    int result = OBJC_SYNC_SUCCESS;

    if (obj) {
        // 查找并生成这个obj对应的SyncData,然后加锁
        SyncData *data = id2data(obj, ACQUIRE);
        ASSERT(data);
        data->mutex.lock(); //递归锁加一次锁
    }
    else {
        // @synchronized(nil) does nothing
        // 如果传入nil, 打印了一个log,然后什么都不做
        if (DebugNilSync) { //dedug代码
            _objc_inform("NIL SYNC DEBUG: @synchronized(nil); set a breakpoint on objc_sync_nil to debug");
        }

        objc_sync_nil();//底层直接调用retq
    }

    return result;
}

BOOL objc_sync_try_enter(id obj) {
    BOOL result = YES;

    if (obj) {
        SyncData *data = id2data(obj, ACQUIRE);
        ASSERT(data);
        result = data->mutex.tryLock();
    }
    else {
        // @synchronized(nil) does nothing
        if (DebugNilSync) {
            _objc_inform("NIL SYNC DEBUG: @synchronized(nil); set a breakpoint on objc_sync_nil to debug");
        }

        objc_sync_nil();
    }

    return result;
}

// End synchronizing on 'obj'.
// Returns OBJC_SYNC_SUCCESS or OBJC_SYNC_NOT_OWNING_THREAD_ERROR
#pragma mark - @synchronized出口 obj 是一个token
int objc_sync_exit(id obj) {
    int result = OBJC_SYNC_SUCCESS;

    if (obj) {
        //RELEASE 释放锁操作
        //
        SyncData *data = id2data(obj, RELEASE);

        if (!data) {
            result = OBJC_SYNC_NOT_OWNING_THREAD_ERROR;
        }
        else {
            //// 尝试解锁,解锁失败也会返回error
            bool okay = data->mutex.tryUnlock();

            if (!okay) {
                result = OBJC_SYNC_NOT_OWNING_THREAD_ERROR;
            }
        }
    }
    else {
        //// 如果这个对象在block执行过程中变成nil了,会什么都不做
        // @synchronized(nil) does nothing
    }

    return result;
}
