## 一期支持的 SQL 语句

### SQL1

CREATE DATABASE [db1];

### SQL2

USE [db];

### SQL3

SHOW DATABASES;

### SQL4

DROP DATABASE [db1];

### SQL5

CREATE TABLE table_name (column_name column_type);

example:

```
CREATE TABLE IF NOT EXISTS `runoob_tbl`(
   `runoob_id` INT UNSIGNED AUTO_INCREMENT,
   `runoob_title` VARCHAR(100) NOT NULL,
   `runoob_author` VARCHAR(40) NOT NULL,
   `submission_date` DATE,
   PRIMARY KEY ( `runoob_id` )
)ENGINE=InnoDB DEFAULT CHARSET=utf8;
```

### SQL6

DROP TABLE table_name ;

### SQL7

插入一行数据

```
INSERT INTO table_name ( field1, field2,...fieldN )
                       VALUES
                       ( value1, value2,...valueN );

INSERT INTO runoob_tbl (runoob_title, runoob_author, submission_date) VALUES ('学习 PHP', '菜鸟教程', '21212');

```

### SQL8

主键点查

```
SELECT * from runoob_tbl WHERE runoob_author='菜鸟教程';
```

### SQL9

索引范围查

```
SELECT * from runoob_tbl WHERE age > '100' and age < '120';
```

### SQL10

更新单个列

```
UPDATE runoob_tbl SET runoob_title='学习 C++' WHERE runoob_id=3;
```

### SQL11

行删除
```
DELETE FROM runoob_tbl WHERE runoob_id=3;
```

### SQL12

范围删除

```
DELETE FROM runoob_tbl WHERE runoob_id < 2;
```

### SQL13

模糊查询

```
SELECT * from runoob_tbl  WHERE runoob_author LIKE '%COM%';
```

### SQL14

排序

```
SELECT * from runoob_tbl ORDER BY submission_date ASC;
```

### SQL15

求平均

```
SELECT AVG(Price) AS AveragePrice FROM Products;
```

### SQL 16

求和

```
SELECT SUM(Quantity) AS TotalItemsOrdered FROM OrderDetails;
```

