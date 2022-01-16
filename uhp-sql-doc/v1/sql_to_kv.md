示例表



[1] CREATE DATABASE  classdb;             

 PUT		 mdatabase_classdb  -> “”;

[2] SHOW DATABASES;       			  
 ITER      database_*
[3] USE classdb;						  
 MEMOP
[4] CREATE TABLE classtab 
( 
Name VARCHAR(100), 
Class VARCHAR(100), 
Score INT, 
PRIMARY KEY(Name)
);
1.PUT meta_db table_classdb_classtab ->  “name^13$$class^13$$score^7”
select * from classtab where title = ‘c’; // ERROR
2.OPEN data_classdb_classtab pmemkv db instance
[5] DROP DATABASE classdb;
remove meta_db database_classdb  -> “”;
remove all table in classdb
[6] DROP TABLE table_name ;
1.remove meta_db table_classdb_classtab -> “###...”
2.delete data_classdb_classtab
[7] INSERT INTO
INSERT INTO classtab 
(
Name, 
Class,
Score
) 
VALUES 
('Tom', 
'B', 
'98');
PUT p_Tom -> Tom$$A$$98 to data_classdb_classtab 
[8]SELECT * from classdb WHERE Name = 'Tom';
GET p_Tom 
Tom$$A$$98

[9]SELECT * from classdb WHERE score > '100' and score < '120';
慢查询
scan all data_db_table_classdb_classtab
满足条件的捞出

快查询
index_db_table_classdb_classtab
idx_classdb_score_88 -> Tom$$A$$98
idx_classdb_score_98 -> Jary$$B$$88

[10]UPDATE classdb 
UPDATE classdb  SET score='78' WHERE Name='Tom';
GET p_Tom
修改后
PUT p_Tom -> Tom$$A$$78  to db 

[11]DELETE 
DELETE FROM classdb WHERE Name='Tom';
data_db_table_classdb_classtab
remove p_Tom

[12] DELETE RANGE
DELETE FROM classdb WHERE score < '99';
scan all, delete 符合条件的
[13] LIKE SELECT
SELECT * from classtab  WHERE Name LIKE '%COM%';
scan all 正则匹配
[14] ORDER BY
SELECT * from classtab ORDER BY submission_date ASC;
scan all data, sort in memory return
submission_date idx
[15] AVG
SELECT AVG(score) AS AverageScore FROM classtab;
scan row data, count score AVG
[16] SUM
SELECT SUM(score) AS TotalScore FROM classtab;
scan all row data, count score SUM
























