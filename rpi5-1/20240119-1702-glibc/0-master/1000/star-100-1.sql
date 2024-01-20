\set aid random(1, 10000000)
select t.* from t
join dim1 on (d1 = dim1.id)
 where t.id = :aid
