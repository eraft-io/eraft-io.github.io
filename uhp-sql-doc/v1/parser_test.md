
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

### Q10

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

### Q11

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

### Q12

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
