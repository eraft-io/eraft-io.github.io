---
title: 动手学习分布式-Go语言基础知识 (Golang eraftkv 版)
date: 2023-08-19 01:09:17
tags:
---

### Go语言优点

首先Go是一门开源的语言，他出生名门Google，社区有强有力的顶级技术人员支撑。它最开始的设计者是Rob Pike，Robert Griesemer，Ken Thompson。 你可以在这个页面找到他们的资料 https://golang.design/history/ 其中Ken Thompson是UNIX系统的发明者。 Go语言对于初学者很友好，很容易在短时间内快速上手，你可以通过这个网站上提供的代码示例快速的入门Go语言：https://gobyexample.com。 作为多核时代的语言，Go语言在设计之初就对并发编程有很多内置的支持，提供的及其健壮的相关标准库。利用它，我们可以快速的编写出高并发的应用程序。 最后，国内外很多大厂都在使用Go语言，它有一个强大的社区，全世界优秀的技术人员开发了丰富的工具生态，有很多脚手架帮你快速的构建应用程序。

### 切片

切片是一个数组的一段，它基于数组构建，并提供了更多丰富的数据操作功能，提供开发者灵活和便利的操作数组结构。 在Go语言内部，切片只是对底层数组数据结构的引用。接下来我们将熟悉如何创建和使用切片，并了解它底层是怎么工作的。

#### 使用字面量列表创建切片

这种方式类似c++里面的初始化列表

```
var s = []int{3, 5, 7, 9, 11, 13, 17}

```
这种方式创建切片的时候，它首先会创建一个数组，然后返回对该数组切片的引用。

从已有数组创建切片

```
// Obtaining a slice from an array `a` 
a[low:high]
```

这里我们对a数组进行切割得到切片，这个操作得到的结果是索引[low, high)的元素，生成的切片包括索引低，但是不包括索引高之间的所有数组元素。 
你可以运行下面的示例，理解这个切片操作

```
package main

import "fmt"

func main() {

    var a = [5]string{"Alpha", "Beta", "Gamma", "Delta", "Epsilon"}

    // Creating a slice from the array
    var s []string = a[1:4]

    fmt.Println("Array a = ", a)        

    fmt.Println("Slice s = ", s)        

}        
// output        

Array a =  [Alpha Beta Gamma Delta Epsilon]        

Slice s =  [Beta Gamma Delta]        

```

### 修改切片中的元素

由于切片是引用类型，它指向了底层的数组。所以当我们使用切片引用去修改数组中对应的元素的时候，引用相同数组的其他切片对象也会看到这个修改结果。

```
package main

import "fmt"


func main() {

	a := [7]string{"Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"}


	slice1 := a[1:]

	slice2 := a[3:]


	fmt.Println("------- Before Modifications -------")

	fmt.Println("a  = ", a)

	fmt.Println("slice1 = ", slice1)

	fmt.Println("slice2 = ", slice2)


	slice1[0] = "TUE"

	slice1[1] = "WED"

	slice1[2] = "THU"


	slice2[1] = "FRIDAY"


	fmt.Println("\n-------- After Modifications --------")

	fmt.Println("a  = ", a)

	fmt.Println("slice1 = ", slice1)

	fmt.Println("slice2 = ", slice2)

}


// Output


------- Before Modifications -------

a  =  [Mon Tue Wed Thu Fri Sat Sun]

slice1 =  [Tue Wed Thu Fri Sat Sun]

slice2 =  [Thu Fri Sat Sun]


type: post

-------- After Modifications --------

a  =  [Mon TUE WED THU FRIDAY Sat Sun]

slice1 =  [TUE WED THU FRIDAY Sat Sun]

slice2 =  [THU FRIDAY Sat Sun]
```

例如上面这个示例，slice2的修改操作在slice1中是能被看到的, slice1的修改在slice2也能被看到。

### 切片底层结构

一个切片由三个部分组成，如图

1.一个指向底层数组的指针Ptr
2.切片所包含数组段的长度Len
3.切片的容量Cap

![](/images/slice01.png)

我们看一个具体的切片结构的底层示例：

```
var a = [6]int{10, 20, 30, 40, 50, 60} 
var s = [1:4]
```

s在Go内部是这样表示的： 

![](/images/slice02.png)

一个切片的长度和容量我们是可以通过len(), cap()函数获取的，例如我们可以通过下面的方式获取s的长度和容量。

```
package main

import "fmt"

func main() {

	a := [6]int{10, 20, 30, 40, 50, 60}
	s := a[1:4]
	fmt.Printf("s = %v, len = %d, cap = %d\n", s, len(s), cap(s))
}

// output

s = [20 30 40], len = 3, cap = 5
```

### Goruntine

Goruntine是由Go运行时所管理的一个轻量级的线程，一个Go程序中的Goroutines在相同的地址空间中运行，因此对共享内存的访问必须同步。 
我们运行一个简单地示例来看看：

```
package main
    

import (

	"fmt"

	"time"

)


func say(s string) {

	for i := 0; i < 5; i++ {

		time.Sleep(100 * time.Millisecond)

		fmt.Println(s)

	}

}


func main() {

	go say("world")

	say("hello")

}


// output


hello

world

hello

world

hello

world

world

hello

hello
```

我们可以看到主线程中say("hello")和goruntine的say("world")在交替的输出，它们在同时的运行，在其他语言做这个事情先要创建线程，然后绑定相关的执行函数，而Go语言直接把并发设计到了编译器语言支持层面，用go关键字就可以轻松地创建轻量级的线程。


#### 捐赠

整理这本书耗费了我们大量的时间和精力。如果你觉得有帮助，一瓶矿泉水的价格支持我们继续输出优质的分布式存储知识体系，2.99¥，感谢大家的支持。

![](/images/alipay.jpeg)

[下载 PDF 版本](https://github.com/eraft-io/eraft-io.github.io/blob/eraft_home/docs/resources/eraft_book.pdf)


<script src="https://giscus.app/client.js"
    data-repo="eraft-io/eraft-io.github.io"
    data-repo-id="MDEwOlJlcG9zaXRvcnkzOTYyMDM3NjU="
    data-category="General"
    data-category-id="DIC_kwDOF52W9c4CRblA"
    data-mapping="pathname"
    data-strict="0"
    data-reactions-enabled="1"
    data-emit-metadata="0"
    data-input-position="bottom"
    data-theme="preferred_color_scheme"
    data-lang="zh-CN"
    crossorigin="anonymous"
    async>
</script>

<script async src="//busuanzi.ibruce.info/busuanzi/2.3/busuanzi.pure.mini.js"></script>
<span id="busuanzi_container_site_pv">本站总访问量<span id="busuanzi_value_site_pv"></span>次</span>
