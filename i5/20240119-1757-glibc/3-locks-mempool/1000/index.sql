\set aid random(1, 100000 * 1000)
select * from t where id = :aid;
