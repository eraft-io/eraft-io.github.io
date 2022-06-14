Flex 和 Bison 介绍，flex 和 bison 是用来生成程序的工具，它们生成的程序能够处理结构化的输入。最开始它们是用来生成编译器的，但是逐渐广泛的在很多领域使用。

要搞懂 UHP-SQL parser 模块的原理，必须了解 flex 和 bison 的使用。

我们先来学习一个简单的分析文本单词数和行数的 flex 程序


1.代码 fb1-1.l

```
/* just like Unix wc */
%{
int chars = 0;
int words = 0;
int lines = 0;
%}

%%

[a-zA-Z]+  { words++; chars += strlen(yytext); }
\n         { chars++; lines++; }
.          { chars++; }

%%

main(int argc, char **argv)
{
  yylex();
  printf("%8d%8d%8d\n", lines, words, chars);
}

// 保存为 fb1-1.l
```

2.环境准备

```
// 在 centos7 上
// 安装 flex 开发依赖

yum -y install flex-devel

[root@67bbd0b6666e flex_bison]#flex fb1-1.l
[root@67bbd0b6666e flex_bison]#cc lex.yy.c -lfl
[root@67bbd0b6666e flex_bison]#./a.out
[root@67bbd0b6666e flex_bison]# ls
a.out  fb1_1.1  lex.yy.c
[root@67bbd0b6666e flex_bison]# ./a.out
Flex and Bison are tools for building programs that handle structured input. They were originally tools for building compilers, but they have proven to be useful in many other areas. In this first chapter, we’ll start by looking at a little (but not too much) of the theory behind them, and then we’ll dive into some examples of their use.
       1      62     344

// 运行 ./a.out 输入文本后，^D 可以拿到分析结果 
```
