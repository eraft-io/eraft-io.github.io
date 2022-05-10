
## UHP-SQL 对这 22 个 TPCH SQL 进行 parser 结果测试

### Q1. PASS

```

// l_shipdate <= '19981201' 这里数据库应该拿到日期先转换成 UNIX 时间戳，底层存储是 UNIX 时间戳来对比

root@aa959a7b3842:/UHP-SQL/build/parser# ./parser_demo 'select
l_returnflag,
l_linestatus,
sum(l_quantity) as sum_qty,
sum(l_extendedprice) as sum_base_price,
sum(l_extendedprice*(1-l_discount)) as sum_disc_price,
sum(l_extendedprice*(1-l_discount)*(1+l_tax)) as sum_charge,
avg(l_quantity) as avg_qty,
avg(l_extendedprice) as avg_price,
avg(l_discount) as avg_disc,
count(*) as count_order
from
lineitem
where
l_shipdate <= '19981201'
group by
l_returnflag,
l_linestatus
order by
l_returnflag,
l_linestatus;'
Parsed successfully!
Number of statements: 1
SelectStatement
	Fields:
		l_returnflag
		l_linestatus
		sum
			l_quantity
			Alias
				sum_qty
		sum
			l_extendedprice
			Alias
				sum_base_price
		sum
			*
				l_extendedprice
				-
					1
					l_discount
			Alias
				sum_disc_price
		sum
			*
				*
					l_extendedprice
					-
						1
						l_discount
				+
					1
					l_tax
			Alias
				sum_charge
		avg
			l_quantity
			Alias
				avg_qty
		avg
			l_extendedprice
			Alias
				avg_price
		avg
			l_discount
			Alias
				avg_disc
		count
			*
			Alias
				count_order
	Sources:
		lineitem
	Search Conditions:
		<=
			l_shipdate
			19981201
	GroupBy:
		l_returnflag
		l_linestatus
	OrderBy:
		l_returnflag
		ascending
		l_linestatus
		ascending

```

### Q2. PASS

```
root@aa959a7b3842:/UHP-SQL/build/parser# ./parser_demo 'select
> s_acctbal,
> s_name,
> n_name,
> p_partkey,
> p_mfgr,
> s_address,
> s_phone,
> s_comment
> from
> part,
> supplier,
> partsupp,
> nation,
> region
> where
> p_partkey = ps_partkey
> and s_suppkey = ps_suppkey
> and p_size = 25
> and p_type like "TYPE"
> and s_nationkey = n_nationkey
> and n_regionkey = r_regionkey
> and r_name = "REGION"
> and ps_supplycost = (
> select
> min(ps_supplycost)
> from
> partsupp, supplier,
> nation, region
> where
> p_partkey = ps_partkey
> and s_suppkey = ps_suppkey
> and s_nationkey = n_nationkey
> and n_regionkey = r_regionkey
> and r_name = "REGION"
> )
> order by
> s_acctbal desc,
> n_name,
> s_name,
> p_partkey;'
Parsed successfully!
Number of statements: 1
SelectStatement
	Fields:
		s_acctbal
		s_name
		n_name
		p_partkey
		p_mfgr
		s_address
		s_phone
		s_comment
	Sources:
		part
		supplier
		partsupp
		nation
		region
	Search Conditions:
		AND
			AND
				AND
					AND
						AND
							AND
								AND
									=
										p_partkey
										ps_partkey
									=
										s_suppkey
										ps_suppkey
								=
									p_size
									25
							LIKE
								p_type
								TYPE
						=
							s_nationkey
							n_nationkey
					=
						n_regionkey
						r_regionkey
				=
					r_name
					REGION
			=
				ps_supplycost
				SelectStatement
					Fields:
						min
							ps_supplycost
					Sources:
						partsupp
						supplier
						nation
						region
					Search Conditions:
						AND
							AND
								AND
									AND
										=
											p_partkey
											ps_partkey
										=
											s_suppkey
											ps_suppkey
									=
										s_nationkey
										n_nationkey
								=
									n_regionkey
									r_regionkey
							=
								r_name
								REGION
	OrderBy:
		s_acctbal
		descending
		n_name
		ascending
		s_name
		ascending
		p_partkey
		ascending
```

### Q3. PASS

```
didi@didideMacBook-Pro example % ./example 'select
l_orderkey,
sum(l_extendedprice*(1-l_discount)) as revenue, o_orderdate,
o_shippriority
from
customer,
orders,
lineitem where
c_mktsegment = 'SEGMENT' and c_custkey = o_custkey
and l_orderkey = o_orderkey and o_orderdate < '19981201' and l_shipdate > '19981101'
group by l_orderkey,
o_orderdate,
o_shippriority order by
revenue desc, o_orderdate;'
Parsed successfully!
Number of statements: 1
SelectStatement
	Fields:
		l_orderkey
		sum
			*
				l_extendedprice
				-
					1
					l_discount
			Alias
				revenue
		o_orderdate
		o_shippriority
	Sources:
		customer
		orders
		lineitem
	Search Conditions:
		AND
			AND
				AND
					AND
						=
							c_mktsegment
							SEGMENT
						=
							c_custkey
							o_custkey
					=
						l_orderkey
						o_orderkey
				<
					o_orderdate
					19981201
			>
				l_shipdate
				19981101
	GroupBy:
		l_orderkey
		o_orderdate
		o_shippriority
	OrderBy:
		revenue
		descending
		o_orderdate
		ascending
```

### Q4. PART SUPPORT

```
didi@didideMacBook-Pro example % ./example 'select
o_orderpriority,
count(*) as order_count from
orders where
o_orderdate >= '19981201'
and o_orderdate < '19981203' and exists (
select
*
from
lineitem
where
l_orderkey = o_orderkey
and l_commitdate < l_receiptdate
) group by
o_orderpriority order by
o_orderpriority;'
Parsed successfully!
Number of statements: 1
SelectStatement
	Fields:
		o_orderpriority
		count
			*
			Alias
				order_count
	Sources:
		orders
	Search Conditions:
		AND
			AND
				>=
					o_orderdate
					19981201
				<
					o_orderdate
					19981203
			EXISTS
	GroupBy:
		o_orderpriority
	OrderBy:
		o_orderpriority
		ascending
```

### Q5. PASS

```
didi@didideMacBook-Pro example % ./example 'select
n_name,
sum(l_extendedprice * (1 - l_discount)) as revenue from
customer, orders, lineitem, supplier, nation, region
where
c_custkey = o_custkey
and l_orderkey = o_orderkey and l_suppkey = s_suppkey and c_nationkey = s_nationkey and s_nationkey = n_nationkey and n_regionkey = r_regionkey and r_name = 'REGION'
and o_orderdate >=  '19981201'
and o_orderdate <  '19981208' group by
n_name order by
revenue desc;'
Parsed successfully!
Number of statements: 1
SelectStatement
	Fields:
		n_name
		sum
			*
				l_extendedprice
				-
					1
					l_discount
			Alias
				revenue
	Sources:
		customer
		orders
		lineitem
		supplier
		nation
		region
	Search Conditions:
		AND
			AND
				AND
					AND
						AND
							AND
								AND
									AND
										=
											c_custkey
											o_custkey
										=
											l_orderkey
											o_orderkey
									=
										l_suppkey
										s_suppkey
								=
									c_nationkey
									s_nationkey
							=
								s_nationkey
								n_nationkey
						=
							n_regionkey
							r_regionkey
					=
						r_name
						REGION
				>=
					o_orderdate
					19981201
			<
				o_orderdate
				19981208
	GroupBy:
		n_name
	OrderBy:
		revenue
		descending
```

### Q6 PASS

```
didi@didideMacBook-Pro example % ./example 'select
sum(l_extendedprice*l_discount) as revenue
from
lineitem
where
l_shipdate >= '19981201'
and l_shipdate < '19981209'
and l_discount between 0.09 - 0.01 and 0.09 + 0.01 and l_quantity < 24;'
Parsed successfully!
Number of statements: 1
SelectStatement
	Fields:
		sum
			*
				l_extendedprice
				l_discount
			Alias
				revenue
	Sources:
		lineitem
	Search Conditions:
		AND
			AND
				AND
					>=
						l_shipdate
						19981201
					<
						l_shipdate
						19981209
				BETWEEN
					l_discount
					-
						0.09
						0.01
					+
						0.09
						0.01
			<
				l_quantity
				24
```

### Q7 PASS

```
didi@didideMacBook-Pro example % ./example 'select
supp_nation,
cust_nation,
l_year, sum(volume) as revenue from (
select
n1.n_name as supp_nation,
n2.n_name as cust_nation,
extract(year from l_shipdate) as l_year, l_extendedprice * (1 - l_discount) as volume
from
supplier,
lineitem, orders, customer, nation n1, nation n2
where
s_suppkey = l_suppkey
and o_orderkey = l_orderkey
and c_custkey = o_custkey
and s_nationkey = n1.n_nationkey and c_nationkey = n2.n_nationkey and (
(n1.n_name = 'cn' and n2.n_name = 'us') or (n1.n_name = 'us' and n2.n_name = 'cn')
)
and l_shipdate between '1995-01-01' and '1996-12-31' ) as shipping
group by supp_nation,
cust_nation,
l_year order by
supp_nation, cust_nation, l_year;'
Parsed successfully!
Number of statements: 1
SelectStatement
	Fields:
		supp_nation
		cust_nation
		l_year
		sum
			volume
			Alias
				revenue
	Sources:
		SelectStatement
			Fields:
				n_name
					Table:
						n1
					Alias
						supp_nation
				n_name
					Table:
						n2
					Alias
						cust_nation
				EXTRACT
					YEAR
					l_shipdate
					Alias
						l_year
				*
					l_extendedprice
					-
						1
						l_discount
					Alias
						volume
			Sources:
				supplier
				lineitem
				orders
				customer
				nation
					Alias
						n1
				nation
					Alias
						n2
			Search Conditions:
				AND
					AND
						AND
							AND
								AND
									AND
										=
											s_suppkey
											l_suppkey
										=
											o_orderkey
											l_orderkey
									=
										c_custkey
										o_custkey
								=
									s_nationkey
									n_nationkey
										Table:
											n1
							=
								c_nationkey
								n_nationkey
									Table:
										n2
						OR
							AND
								=
									n_name
										Table:
											n1
									cn
								=
									n_name
										Table:
											n2
									us
							AND
								=
									n_name
										Table:
											n1
									us
								=
									n_name
										Table:
											n2
									cn
					BETWEEN
						l_shipdate
						-
							-
								1995
								1
							1
						-
							-
								1996
								12
							31
			Alias
				shipping
	GroupBy:
		supp_nation
		cust_nation
		l_year
	OrderBy:
		supp_nation
		ascending
		cust_nation
		ascending
		l_year
		ascending
```

### Q8 PASS

```
didi@didideMacBook-Pro example % ./example 'select
o_year,
sum(case
when nation = "NATION"
then volume
else 0
end) / sum(volume) as mkt_share
from (
select
extract(year from o_orderdate) as o_year, l_extendedprice * (1-l_discount) as volume, n2.n_name as nation
from
part,
supplier, lineitem, orders, customer, nation n1, nation n2, region
where
p_partkey = l_partkey
and s_suppkey = l_suppkey
and l_orderkey = o_orderkey
and o_custkey = c_custkey
and c_nationkey = n1.n_nationkey and n1.n_regionkey = r_regionkey and r_name = "REGION"
and s_nationkey = n2.n_nationkey
and o_orderdate between "1995-01-01" and "1996-12-31" and p_type = "TYPE"
) as all_nations group by
o_year order by
o_year;'
Parsed successfully!
Number of statements: 1
SelectStatement
	Fields:
		o_year
		/
			sum
				CASE
					0
			sum
				volume
			Alias
				mkt_share
	Sources:
		SelectStatement
			Fields:
				EXTRACT
					YEAR
					o_orderdate
					Alias
						o_year
				*
					l_extendedprice
					-
						1
						l_discount
					Alias
						volume
				n_name
					Table:
						n2
					Alias
						nation
			Sources:
				part
				supplier
				lineitem
				orders
				customer
				nation
					Alias
						n1
				nation
					Alias
						n2
				region
			Search Conditions:
				AND
					AND
						AND
							AND
								AND
									AND
										AND
											AND
												AND
													=
														p_partkey
														l_partkey
													=
														s_suppkey
														l_suppkey
												=
													l_orderkey
													o_orderkey
											=
												o_custkey
												c_custkey
										=
											c_nationkey
											n_nationkey
												Table:
													n1
									=
										n_regionkey
											Table:
												n1
										r_regionkey
								=
									r_name
									REGION
							=
								s_nationkey
								n_nationkey
									Table:
										n2
						BETWEEN
							o_orderdate
							1995-01-01
							1996-12-31
					=
						p_type
						TYPE
			Alias
				all_nations
	GroupBy:
		o_year
	OrderBy:
		o_year
		ascending
```

### Q9 PASS

```

didi@didideMacBook-Pro example % ./example 'select
nation,
o_year,
sum(amount) as sum_profit from (
select
n_name as nation,
extract(year from o_orderdate) as o_year,
l_extendedprice * (1 - l_discount) - ps_supplycost * l_quantity as amount from
part, supplier, lineitem, partsupp, orders, nation
where
s_suppkey = l_suppkey
and ps_suppkey = l_suppkey and ps_partkey = l_partkey
and p_partkey = l_partkey
and o_orderkey = l_orderkey and s_nationkey = n_nationkey and p_name like 'COLOR'
) as profit group by
nation,
o_year order by
nation, o_year desc;'
Parsed successfully!
Number of statements: 1
SelectStatement
	Fields:
		nation
		o_year
		sum
			amount
			Alias
				sum_profit
	Sources:
		SelectStatement
			Fields:
				n_name
					Alias
						nation
				EXTRACT
					YEAR
					o_orderdate
					Alias
						o_year
				-
					*
						l_extendedprice
						-
							1
							l_discount
					*
						ps_supplycost
						l_quantity
					Alias
						amount
			Sources:
				part
				supplier
				lineitem
				partsupp
				orders
				nation
			Search Conditions:
				AND
					AND
						AND
							AND
								AND
									AND
										=
											s_suppkey
											l_suppkey
										=
											ps_suppkey
											l_suppkey
									=
										ps_partkey
										l_partkey
								=
									p_partkey
									l_partkey
							=
								o_orderkey
								l_orderkey
						=
							s_nationkey
							n_nationkey
					LIKE
						p_name
						COLOR
			Alias
				profit
	GroupBy:
		nation
		o_year
	OrderBy:
		nation
		ascending
		o_year
		descending

```

### Q10 PASS

```

didi@didideMacBook-Pro example % ./example 'select
c_custkey,
c_name,
sum(l_extendedprice * (1 - l_discount)) as revenue, c_acctbal,
n_name,
c_address,
c_phone,
c_comment
from
customer,
orders, lineitem, nation
where
c_custkey = o_custkey
and l_orderkey = o_orderkey
and o_orderdate >=  'DATE1'
and o_orderdate <  'DATE2' and l_returnflag = 'R'
and c_nationkey = n_nationkey
group by c_custkey,
c_name, c_acctbal, c_phone, n_name, c_address, c_comment
order by
revenue desc;'
Parsed successfully!
Number of statements: 1
SelectStatement
	Fields:
		c_custkey
		c_name
		sum
			*
				l_extendedprice
				-
					1
					l_discount
			Alias
				revenue
		c_acctbal
		n_name
		c_address
		c_phone
		c_comment
	Sources:
		customer
		orders
		lineitem
		nation
	Search Conditions:
		AND
			AND
				AND
					AND
						AND
							=
								c_custkey
								o_custkey
							=
								l_orderkey
								o_orderkey
						>=
							o_orderdate
							DATE1
					<
						o_orderdate
						DATE2
				=
					l_returnflag
					R
			=
				c_nationkey
				n_nationkey
	GroupBy:
		c_custkey
		c_name
		c_acctbal
		c_phone
		n_name
		c_address
		c_comment
	OrderBy:
		revenue
		descending

```

### Q11 PASS

```
didi@didideMacBook-Pro example % ./example 'select
ps_partkey,
sum(ps_supplycost * ps_availqty) as value from
partsupp, supplier, nation
where
ps_suppkey = s_suppkey
and s_nationkey = n_nationkey
and n_name = "NATION" group by
ps_partkey having
sum(ps_supplycost * ps_availqty) > (
select
sum(ps_supplycost * ps_availqty) * 0.03
from
partsupp,
supplier,
nation where
ps_suppkey = s_suppkey
and s_nationkey = n_nationkey and n_name = "NATION"
) order by
value desc;'
Parsed successfully!
Number of statements: 1
SelectStatement
	Fields:
		ps_partkey
		sum
			*
				ps_supplycost
				ps_availqty
			Alias
				value
	Sources:
		partsupp
		supplier
		nation
	Search Conditions:
		AND
			AND
				=
					ps_suppkey
					s_suppkey
				=
					s_nationkey
					n_nationkey
			=
				n_name
				NATION
	GroupBy:
		ps_partkey
	Having:
		>
			sum
				*
					ps_supplycost
					ps_availqty
			SelectStatement
				Fields:
					*
						sum
							*
								ps_supplycost
								ps_availqty
						0.03
				Sources:
					partsupp
					supplier
					nation
				Search Conditions:
					AND
						AND
							=
								ps_suppkey
								s_suppkey
							=
								s_nationkey
								n_nationkey
						=
							n_name
							NATION
	OrderBy:
		value
		descending

```

### Q12 PASS

```
didi@didideMacBook-Pro example % ./example 'select
l_shipmode,
sum(case
when o_orderpriority ='1-URGENT'
or o_orderpriority ='2-HIGH' then 1
else 0
end) as high_line_count,
sum(case
when o_orderpriority <> '1-URGENT'
and o_orderpriority <> '2-HIGH' then 1
else 0
end) as low_line_count
from
orders,
lineitem where
o_orderkey = l_orderkey
and l_shipmode in ('SHIPMODE1', 'SHIPMODE2') and l_commitdate < l_receiptdate
and l_shipdate < l_commitdate
and l_receiptdate >= 'DATE1'
and l_receiptdate <  'DATE2'
group by l_shipmode
order by l_shipmode;'
Parsed successfully!
Number of statements: 1
SelectStatement
	Fields:
		l_shipmode
		sum
			CASE
				0
			Alias
				high_line_count
		sum
			CASE
				0
			Alias
				low_line_count
	Sources:
		orders
		lineitem
	Search Conditions:
		AND
			AND
				AND
					AND
						AND
							=
								o_orderkey
								l_orderkey
							IN
								l_shipmode
								SHIPMODE1
								SHIPMODE2
						<
							l_commitdate
							l_receiptdate
					<
						l_shipdate
						l_commitdate
				>=
					l_receiptdate
					DATE1
			<
				l_receiptdate
				DATE2
	GroupBy:
		l_shipmode
	OrderBy:
		l_shipmode
		ascending
```

### Q13

```

didi@didideMacBook-Pro example % ./example 'select
c_count, count(*) as custdist
from (
select
count(o_orderkey) from
customer left outer join orders on c_custkey = o_custkey
and o_comment not like "%WORD1%WORD2%"
group by c_custkey
)as c_orders (c_custkey, c_count) group by
c_count order by
custdist desc, c_count desc;'
Parsed successfully!
Number of statements: 1
SelectStatement
	Fields:
		c_count
		count
			*
			Alias
				custdist
	Sources:
		SelectStatement
			Fields:
				count
					o_orderkey
			Sources:
				Join Table
					Left
						customer
					Right
						orders
					Join Condition
						AND
							=
								c_custkey
								o_custkey
							NOT LIKE
								o_comment
								%WORD1%WORD2%
			GroupBy:
				c_custkey
			Alias
				c_orders
					c_custkey
					c_count
	GroupBy:
		c_count
	OrderBy:
		custdist
		descending
		c_count
		descending

```

### Q14

```
didi@didideMacBook-Pro example % ./example 'select
100.00 * sum(case
when p_type like "PROMO%"
then l_extendedprice*(1-l_discount) else 0
end) / sum(l_extendedprice * (1 - l_discount)) as promo_revenue from
lineitem,
part where
l_partkey = p_partkey
and l_shipdate >= "DATE1"
and l_shipdate <  "DATE2";'
Parsed successfully!
Number of statements: 1
SelectStatement
	Fields:
		/
			*
				100
				sum
					CASE
						0
			sum
				*
					l_extendedprice
					-
						1
						l_discount
			Alias
				promo_revenue
	Sources:
		lineitem
		part
	Search Conditions:
		AND
			AND
				=
					l_partkey
					p_partkey
				>=
					l_shipdate
					DATE1
			<
				l_shipdate
				DATE2

```

### Q15 NOT SUPPORT VIEW

```

create view revenue_1 (supplier_no, total_revenue) as select
l_suppkey,
sum(l_extendedprice * (1 - l_discount)) from
lineitem where
l_shipdate >= "DATE0"
and l_shipdate < "DATE1"
l_suppkey;

select
s_suppkey,
s_name, s_address, s_phone, total_revenue
from
supplier,
revenue_1 where
s_suppkey = supplier_no
and total_revenue = (
    select
max(total_revenue)
from
revenue_1
) order by
s_suppkey;

```

### Q16

```
didi@didideMacBook-Pro example % ./example 'select
p_brand,
p_type,
p_size,
count(distinct ps_suppkey) as supplier_cnt
from
partsupp,
part
where
p_partkey = ps_partkey
and p_brand <> "BRAND"
and p_type not like "TYPE%"
and p_size in ("SIZE1", "SIZE2", "SIZE3", "SIZE4", "SIZE5", "SIZE6", "SIZE7", "SIZE8") and ps_suppkey not in (
select
s_suppkey
from
supplier
where
s_comment like "%Customer%Complaints%")
group by
p_brand, p_type, p_size
order by
supplier_cnt desc,
p_brand, p_type, p_size;'
Parsed successfully!
Number of statements: 1
SelectStatement
	Fields:
		p_brand
		p_type
		p_size
		count
			ps_suppkey
			Alias
				supplier_cnt
	Sources:
		partsupp
		part
	Search Conditions:
		AND
			AND
				AND
					AND
						=
							p_partkey
							ps_partkey
						!=
							p_brand
							BRAND
					NOT LIKE
						p_type
						TYPE%
				IN
					p_size
					SIZE1
					SIZE2
					SIZE3
					SIZE4
					SIZE5
					SIZE6
					SIZE7
					SIZE8
			NOT
				IN
					ps_suppkey
	GroupBy:
		p_brand
		p_type
		p_size
	OrderBy:
		supplier_cnt
		descending
		p_brand
		ascending
		p_type
		ascending
		p_size
		ascending

```

### Q17

```

didi@didideMacBook-Pro example % ./example 'select
sum(l_extendedprice) / 7.0 as avg_yearly
from
lineitem,
part where
p_partkey = l_partkey
and p_brand = "BRAND"
and p_container = "CONTAINER" and l_quantity < (
select
0.2 * avg(l_quantity)
from
lineitem
where
l_partkey = p_partkey
);'
Parsed successfully!
Number of statements: 1
SelectStatement
	Fields:
		/
			sum
				l_extendedprice
			7
			Alias
				avg_yearly
	Sources:
		lineitem
		part
	Search Conditions:
		AND
			AND
				AND
					=
						p_partkey
						l_partkey
					=
						p_brand
						BRAND
				=
					p_container
					CONTAINER
			<
				l_quantity
				SelectStatement
					Fields:
						*
							0.2
							avg
								l_quantity
					Sources:
						lineitem
					Search Conditions:
						=
							l_partkey
							p_partkey

```

### Q18

```
didi@didideMacBook-Pro example % ./example 'select
c_name, c_custkey, o_orderkey, o_orderdate, o_totalprice, sum(l_quantity)
from
customer,
orders,
lineitem where
o_orderkey in ( select
l_orderkey from
lineitem group by
l_orderkey having
sum(l_quantity) > 2.3
)
and c_custkey = o_custkey and o_orderkey = l_orderkey
group by c_name,
c_custkey, o_orderkey, o_orderdate, o_totalprice
order by
o_totalprice desc,
o_orderdate;'
Parsed successfully!
Number of statements: 1
SelectStatement
	Fields:
		c_name
		c_custkey
		o_orderkey
		o_orderdate
		o_totalprice
		sum
			l_quantity
	Sources:
		customer
		orders
		lineitem
	Search Conditions:
		AND
			AND
				IN
					o_orderkey
				=
					c_custkey
					o_custkey
			=
				o_orderkey
				l_orderkey
	GroupBy:
		c_name
		c_custkey
		o_orderkey
		o_orderdate
		o_totalprice
	OrderBy:
		o_totalprice
		descending
		o_orderdate
		ascending

```

### Q19

```

didi@didideMacBook-Pro example % ./example 'select
sum(l_extendedprice * (1 - l_discount) ) as revenue
from
lineitem,
part where
(
p_partkey = l_partkey
and p_brand = "BRAND1"
and p_container in ( "SM CASE", "SM BOX", "SM PACK", "SM PKG") and l_quantity >= 4.5 and l_quantity <= 4.5 + 10 and p_size between 1 and 5
and l_shipmode in ("AIR", "AIR REG")
and l_shipinstruct = "DELIVER IN PERSON"
)
or
(
p_partkey = l_partkey
and p_brand = "BRAND2"
and p_container in ("MED BAG", "MED BOX", "MED PKG", "MED PACK") and l_quantity >= 3.456 and l_quantity <= 4.56 + 10 and p_size between 1 and 10
and l_shipmode in ("AIR", "AIR REG")
and l_shipinstruct = "DELIVER IN PERSON"
)
or
(
p_partkey = l_partkey
and p_brand = "BRAND3"
and p_container in ( "LG CASE", "LG BOX", "LG PACK", "LG PKG") and l_quantity >= 3.45 and l_quantity <= 3.45 + 10 and p_size between 1 and 15
and l_shipmode in ("AIR", "AIR REG")
and l_shipinstruct = "DELIVER IN PERSON"
);'
Parsed successfully!
Number of statements: 1
SelectStatement
	Fields:
		sum
			*
				l_extendedprice
				-
					1
					l_discount
			Alias
				revenue
	Sources:
		lineitem
		part
	Search Conditions:
		OR
			OR
				AND
					AND
						AND
							AND
								AND
									AND
										AND
											=
												p_partkey
												l_partkey
											=
												p_brand
												BRAND1
										IN
											p_container
											SM CASE
											SM BOX
											SM PACK
											SM PKG
									>=
										l_quantity
										4.5
								<=
									l_quantity
									+
										4.5
										10
							BETWEEN
								p_size
								1
								5
						IN
							l_shipmode
							AIR
							AIR REG
					=
						l_shipinstruct
						DELIVER IN PERSON
				AND
					AND
						AND
							AND
								AND
									AND
										AND
											=
												p_partkey
												l_partkey
											=
												p_brand
												BRAND2
										IN
											p_container
											MED BAG
											MED BOX
											MED PKG
											MED PACK
									>=
										l_quantity
										3.456
								<=
									l_quantity
									+
										4.56
										10
							BETWEEN
								p_size
								1
								10
						IN
							l_shipmode
							AIR
							AIR REG
					=
						l_shipinstruct
						DELIVER IN PERSON
			AND
				AND
					AND
						AND
							AND
								AND
									AND
										=
											p_partkey
											l_partkey
										=
											p_brand
											BRAND3
									IN
										p_container
										LG CASE
										LG BOX
										LG PACK
										LG PKG
								>=
									l_quantity
									3.45
							<=
								l_quantity
								+
									3.45
									10
						BETWEEN
							p_size
							1
							15
					IN
						l_shipmode
						AIR
						AIR REG
				=
					l_shipinstruct
					DELIVER IN PERSON

```

### Q20

```
didi@didideMacBook-Pro example % ./example 'select
s_name,
s_address from
supplier, nation where
s_suppkey in ( select
ps_suppkey from
partsupp where
ps_partkey in ( select
p_partkey from
part where
p_name like "%COLOR%")
and ps_availqty > (
    select
0.5 * sum(l_quantity)
from
lineitem
where
l_partkey = ps_partkey
and l_suppkey = ps_suppkey
and l_shipdate >= "1202393"
and l_shipdate < "1202343434"
) )
and s_nationkey = n_nationkey
and n_name = "NATION"
order by
s_name;'
Parsed successfully!
Number of statements: 1
SelectStatement
	Fields:
		s_name
		s_address
	Sources:
		supplier
		nation
	Search Conditions:
		AND
			AND
				IN
					s_suppkey
				=
					s_nationkey
					n_nationkey
			=
				n_name
				NATION
	OrderBy:
		s_name
		ascending

```

### Q21

```
didi@didideMacBook-Pro example % ./example 'select
s_name,
count(*) as numwait from
supplier, lineitem l1, orders, nation
where
s_suppkey = l1.l_suppkey
and o_orderkey = l1.l_orderkey
and o_orderstatus = "F"
and l1.l_receiptdate > l1.l_commitdate and exists (
select
*
from
lineitem l2
where
l2.l_orderkey = l1.l_orderkey
and l2.l_suppkey <> l1.l_suppkey
)
and not exists (
select
*
from
lineitem l3
where
l3.l_orderkey = l1.l_orderkey
and l3.l_suppkey <> l1.l_suppkey
and l3.l_receiptdate > l3.l_commitdate
)
and s_nationkey = n_nationkey and n_name = "NATION"
group by s_name
order by
numwait desc,
s_name;'
Parsed successfully!
Number of statements: 1
SelectStatement
	Fields:
		s_name
		count
			*
			Alias
				numwait
	Sources:
		supplier
		lineitem
			Alias
				l1
		orders
		nation
	Search Conditions:
		AND
			AND
				AND
					AND
						AND
							AND
								AND
									=
										s_suppkey
										l_suppkey
											Table:
												l1
									=
										o_orderkey
										l_orderkey
											Table:
												l1
								=
									o_orderstatus
									F
							>
								l_receiptdate
									Table:
										l1
								l_commitdate
									Table:
										l1
						EXISTS
					NOT
						EXISTS
				=
					s_nationkey
					n_nationkey
			=
				n_name
				NATION
	GroupBy:
		s_name
	OrderBy:
		numwait
		descending
		s_name
		ascending

```

### Q22 NOT SUPPORT

```

select
cntrycode,
count(*) as numcust,
sum(c_acctbal) as totacctbal from (
select
substring(c_phone from 1 for 2) as cntrycode, c_acctbal
from
customer
where
substring(c_phone from 1 for 2) in
("1", "2", "3", "4", "5", "6", "7") and c_acctbal > (
select
avg(c_acctbal)
from
customer
where
c_acctbal > 0.00
and substring (c_phone from 1 for 2) in ("1", "2", "3", "4", "5", "6", "7")
)
and not exists (
select
*
from
orders
where
o_custkey = c_custkey
)
) as custsale
group by cntrycode
order by cntrycode;

```