# Lecture 8 索引并发控制(Index Concurrency Control)

## Index Concurrency Control 索引并发控制

A concurrency control protocol is the method that the DBMS uses to ensure “correct” results for concurrent
operations on a shared object.

并发控制协议是 DBMS 用于确保对共享对象的并发操作得到“正确”结果的方法。

A protocol’s correctness criteria can vary:
    * Logical Correctness: Can I see the data that I am supposed to see? This means that the thread is able to read values that it should be allowed to read.
    * Physical Correctness: Is the internal representation of the object sound? This means that there are not pointers in our data structure that will cause a thread to read invalid memory locations.
    
协议的正确性标准可能会有所不同：
    * 逻辑正确性：我能看到我应该看到的数据吗？这意味着线程能够读取应允许其读取的值。
    * 物理正确性：物体的内部表征是声音吗？这意味着我们的数据结构中没有会导致线程读取无效内存位置的指针。
    
The logical contents of the index is the only thing we care about in this lecture. They are not quite like other database elements so we can treat them differently.

索引的逻辑内容是我们在本讲座中唯一关心的事情。它们与其他数据库元素不太相似，因此我们可以区别对待它们。

## Locks vs. Latches 锁与闩锁
Locks:
* Protects the indexs logical contents from other transactions.
* Held for (mostly) the entire duration of the transaction.
* The DBMS needs to be able to rollback changes.
Latches:
* Protects the critical sections of the indexs internal data structure from other threads.
* Held for operation duration.
* The DBMS does not need to be able to rollback changes.
* Two Modes:
    1. READ: Multiple threads are allowed to read the same item at the same time. A thread can acquire the read latch if another thread has it in read mode.
    2. WRITE: Only one thread is allowed to access the item. A thread cannot acquire a write latch if
another thread holds the latch in any mode.

锁：
* 保护索引逻辑内容免受其他事务的影响。
* 在几乎整个事务期间持有。
* DBMS需要能够回滚更改。

闩：
* 保护索引内部数据结构的关键部分免受其他线程的攻击。
* 在运行期间保持。
* DBMS不需要能够回滚更改。
* 两种模式：
    1. 读取：允许多个线程同时读取同一项目。如果另一个线程处于读取模式，则线程可以获取读取闩锁。
    2. 写入：只允许一个线程访问该项目。在以下情况下，线程无法获取写闩锁另一个线程以任何模式固定闩锁。

## Latch Implementations 闩的实现
The underlying primitive that we can use to implement a latch is through an atomic compare-and-swap (CAS) instruction that modern CPUs provide. With this, a thread can check the contents of a memory location to see whether it has a certain value. If it does, then the CPU will swap the old value with a new
one. Otherwise the memory location remains unmodified.

闩锁实现的基础是现代CPU提供的原子比较和交换（CAS）指令。通过CAS，线程可以检查内存位置的内容，以查看它是否具有特定值。如果是这样，则CPU会将旧值换成新值。否则，内存位置将保持不变。

There are several approaches to implementing a latch in a DBMS. Each approach have different trade-offs in terms of engineering complexity and runtime performance. These test-and-set steps are performed atomically (i.e., no other thread can update the value after one thread checks it but before it updates it).

有几种方法可以在DBMS中实现闩锁。每种方法在工程复杂性和运行时性能方面都有不同的权衡。这些测试和设置步骤是以原子方式执行的（即，在一个线程检查值之后，但在更新值之前，没有其他线程可以更新该值）。

### Blocking OS Mutex 
Use the OS built-in mutex infrastructure as a latch. The futex (fast user-space mutex) is comprised of (1) a spin latch in user-space and (2) a OS-level mutex. If the DBMS can acquire the user-space latch, then the latch is set. It appears as a single latch to the DBMS even though it contains two internal latches. If the DBMS fails to acquire the user-space latch, then it goes down into the kernel and tries to acquire a more expensive mutex. If the DBMS fails to acquire this second mutex, then the thread notifies the OS that it is blocked on the lock and then it is descheduled.

使用操作系统内置互斥体基础结构作为闩锁。futex（快速用户空间互斥体）由（1）用户空间中的旋转闩锁和（2）操作系统级互斥体组成。如果DBMS可以获取用户空间闩锁，则设置闩锁。它显示为DBMS的单个闩锁，即使它包含两个内部闩锁。如果DBMS无法获取用户空间闩锁，则它会进入内核并尝试获取更昂贵的互斥锁。如果DBMS无法获取第二个互斥体，则线程会通知操作系统它在锁上被阻止，然后取消计划。

OS mutex is generally a bad idea inside of DBMSs as it is managed by OS and has large overhead.
* Example: std::mutex
* Advantages: Simple to use and requires no additional coding in DBMS.
* Disadvantages: Expensive and non-scalable (about 25 ns per lock/unlock invocation) because of OS scheduling.

操作系统互斥锁通常是DBMS内部的一个坏主意，因为它是由操作系统管理的，并且开销很大。
* 示例：std：：互斥体
* 优点：易于使用，不需要在DBMS中进行额外的编码。
* 缺点：由于操作系统调度，昂贵且不可扩展（每次锁定/解锁调用约25ns）。

### Test-and-Set Spin Latch (TAS) 
Spin latches are a more efficient alternative to an OS mutex as it is controlled by the DBMSs. A spin latch is essentially a location in memory that threads try to update (e.g., setting a boolean value to true). A thread performs CAS to attempt to update the memory location. If it cannot, then it spins in a while loop forever trying to update it.

* Example: std::atomic<T>
* Advantages: Latch/unlatch operations are efficient (single instruction to lock/unlock).
* Disadvantages: Not scalable nor cache friendly because with multiple threads, the CAS instructions will be executed multiple times in different threads. These wasted instructions will pile up in high contention environments; the threads look busy to the OS even though they are not doing useful work. This leads to cache coherence problems because threads are polling cache lines on other CPUs.
  
自旋锁存器是操作系统互斥锁的更有效的替代方案，因为它由DBMS控制。自旋锁存器本质上是线程尝试更新的内存中的一个位置（例如，将布尔值设置为true）。线程执行CAS以尝试更新内存位置。如果不能，它就会在一个while循环中旋转，永远试图更新它。
* 示例：std::atomic<T>
* 优点：闩锁/解锁操作高效（锁定/解锁单指令）。
* 缺点：不可扩展或缓存友好，因为使用多个线程，CAS指令将在不同的线程中多次执行。这些浪费的指令将堆积在高争用环境中;线程在操作系统上看起来很忙，即使它们没有做有用的工作。这会导致缓存一致性问题，因为线程正在轮询其他 CPU 上的缓存行。


### Reader-Writer Latches
Mutexes and Spin Latches do not differentiate between reads / writes (i.e., they do not support different modes). We need a way to allow for concurrent reads, so if the application has heavy reads it will have better performance because readers can share resources instead of waiting.
  
互斥锁和自旋锁存器不区分读/写（即，它们不支持不同的模式）。我们需要一种方法来允许并发读取，因此，如果应用程序具有大量读取，它将具有更好的性能，因为读取器可以共享资源而不是等待。
读写器闩锁允许在读或写模式下保持闩锁。它跟踪有多少线程保持闩锁，并等待在每种模式下获取闩锁。
  
A Reader-Writer Latch allows a latch to be held in either read or write mode. It keeps track of how many threads hold the latch and are waiting to acquire the latch in each mode.
* Example: This is implemented on top of Spin Latches.
* Advantages: Allows for concurrent readers.
* Disadvantages: The DBMS has to manage read/write queues to avoid starvation. Larger storage overhead than Spin Latches due to additional meta-data.
  
读写器闩锁允许在读或写模式下保持闩锁。它跟踪有多少线程保持闩锁，并等待在每种模式下获取闩锁。
* 示例：这是在自旋锁存器之上实现的。
* 优点：允许并发读取器。
* 缺点：DBMS必须管理读/写队列以避免饥饿。由于额外的元数据，存储开销比自旋锁存器大。
  
## Hash Table Latching  
It is easy to support concurrent access in a static hash table due to the limited ways threads access the data structure. For example, all threads move in the same direction when moving from slot to the next (i.e., top-down). Threads also only access a single page/slot at a time. Thus, deadlocks are not possible in this situation because no two threads could be competing for latches held by the other. To resize the table, take a global latch on the entire table (i.e., in the header page).
  
由于线程访问数据结构的方式有限，因此很容易在静态哈希表中支持并发访问。例如，当从插槽移动到下一个插槽时，所有线程都朝同一方向移动（即自上而下）。线程一次也只能访问单个页面/插槽。因此，在这种情况下不可能出现死锁，因为没有两个线程可以争用另一个线程持有的闩锁。要调整表的大小，请在整个表上（即在页眉页中）进行全局闩锁。
  
Latching in a dynamic hashing scheme (e.g., extendible) is slightly more complicated because there is more shared state to update, but the general approach is the same.
  
动态哈希方案（例如，可扩展）中的闩锁稍微复杂一些，因为要更新的共享状态更多，但一般方法是相同的。

In general, there are two approaches to support latching in a hash table:
* Page Latches: Each page has its own Reader-Writer latch that protects its entire contents. Threads acquire either a read or write latch before they access a page. This decreases parallelism because potentially only one thread can access a page at a time, but accessing multiple slots in a page will be
fast because a thread only has to acquire a single latch.
* Slot Latches: Each slot has its own latch. This increases parallelism because two threads can access different slots in the same page. But it increases the storage and computational overhead of accessing the table because threads have to acquire a latch for every slot they access. The DBMS can use a single mode latch (i.e., Spin Latch) to reduce meta-data and computational overhead.
  
通常，有两种方法可以支持哈希表中的闩锁：
* 页面闩锁：每个页面都有自己的读写器闩锁，可保护其全部内容。线程在访问页面之前获取读取或写入闩锁。这会降低并行性，因为一次可能只有一个线程可以访问一个页面，但访问页面中的多个槽将
快速，因为螺纹只需要获取单个闩锁。
* 插槽闩锁：每个插槽都有自己的闩锁。这增加了并行度，因为两个线程可以访问同一页面中的不同插槽。但它增加了访问表的存储和计算开销，因为线程必须为它们访问的每个插槽获取闩锁。DBMS可以使用单模锁存器（即自旋锁存器）来减少元数据和计算开销。
  
## B+Tree Latching
Lock crabbing/coupling is a protocol to allow multiple threads to access/modify B+Tree at the same time:
1. Get latch for parent.
2. Get latch for child.
3. Release latch for parent if it is deemed safe. A safe node is one that will not split or merge when updated (not full on insertion or more than half full on deletion).
  

Lock crabbing/coupling是一种协议，允许多个线程同时访问/修改B+树：
1. 获取父母节点闩锁。
2. 获取孩子节点闩锁。
3. 如果父母认为安全，请释放闩锁。安全节点是指在更新时不会拆分或合并的节点（插入时不满，删除时超过一半）。
  
### Basic Latch Crabbing Protocl 基础Latch Crabbing协议：
* Search: Start at root and go down, repeatedly acquire latch on child and then unlatch parent.
* Insert/Delete: Start at root and go down, obtaining X latches as needed. Once child is latched, check if it is safe. If the child is safe, release latches on all its ancestors.  
  
* 搜索：从根部开始，然后向下，反复获得对子项的闩锁，然后解开父项的闩锁。
* 插入/删除：从根开始并向下，根据需要获得X闩锁。一旦孩子被锁住，检查它是否安全。如果孩子是安全的，释放其所有祖先的闩锁。 

Improved Lock Crabbing Protocol: The problem with the basic latch crabbing algorithm is that transactions always acquire an exclusive latch on the root for every insert/delete operation. This limits parallelism. 
Instead, we can assume that having to resize (i.e., split/merge nodes) is rare, and thus transactions can acquire shared latches down to the leaf nodes. Each transaction will assume that the path to the target leaf node is safe, and use READ latches and crabbing to reach it, and verify. If any node in the path is not safe, then do previous algorithm (i.e., acquire WRITE latches).
* Search: Same algorithm as before.
* Insert/Delete: Set READ latches as if for search, go to leaf, and set WRITE latch on leaf. If leaf is not safe, release all previous latches, and restart transaction using previous Insert/Delete protocol.  
  
改进的Lock Crabbing协议：基础的Lock Crabbing算法的问题在于，事务始终为每个插入/删除操作获取根上的独占闩锁。这限制了并行性。相反，我们可以假设必须调整大小（即拆分/合并节点）是罕见的，因此事务可以获得共享闩锁到叶节点。每个事务都将假定到目标叶节点的路径是安全的，并使用READ闩锁和crabbing来访问它并进行验证。如果路径中的任何节点不安全，则执行先前的算法（即获取 WRITE闩锁）。
* 搜索：与之前相同的算法。
* 插入/删除：将读闩锁设置为用于搜索，直到到叶节点，并在叶节点上设置写闩锁。如果叶节点不安全，释放所有以前的锁存，并使用以前的插入/删除协议重新启动事务。

## Leaf Node Scans 叶节点扫描
The threads in these protocols acquire latches in a “top-down” manner. This means that a thread can only acquire a latch from a node that is below its current node. If the desired latch is unavailable, the thread must wait until it becomes available. Given this, there can never be deadlocks.

这些协议中的线程以“自上而下”的方式获取闩锁。这意味着线程只能从其当前节点下方的节点获取闩锁。如果所需的闩锁不可用，则线程必须等待，直到它变为可用。鉴于此，永远不会出现僵局。
  
Leaf node scans are susceptible to deadlocks because now we have threads trying to acquire locks in two different directions at the same time (i.e., left-to-right and right-to-left). Index latches do not support deadlock detection or avoidance.
  
叶节点扫描容易受到死锁的影响，因为现在我们有线程尝试同时在两个不同的方向上获取锁（即，从左到右和从右到左）。索引闩锁不支持死锁检测或避免。
  
Thus, the only way we can deal with this problem is through coding discipline. The leaf node sibling latch acquisition protocol must support a “no-wait” mode. That is, B+tree code must cope with failed latch acquisitions. This means that if a thread tries to acquire a latch on a leaf node but that latch is unavailable, then it will immediately abort its operation (releasing any latches that it holds) and then restart the operation.
  
因此，我们处理这个问题的唯一方法是通过编码纪律。叶子节点同级闩锁获取协议必须支持“无等待”模式。也就是说，B+树代码必须应对失败的闩锁获取。这意味着，如果线程尝试获取叶节点上的闩锁，但该闩锁不可用，则它将立即中止其操作（释放它持有的任何闩锁），然后重新启动该操作。
  
