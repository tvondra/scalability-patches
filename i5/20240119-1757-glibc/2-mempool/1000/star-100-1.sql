\set aid random(1, 1000000 * 100)
select t.* from t
join dim1 on (d1 = dim1.id)
 where t.id = :aid
