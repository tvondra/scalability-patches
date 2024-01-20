create table t (id serial primary key
, d1 int
);
create table dim1 (id serial primary key, val int);
insert into dim1 select i, i from generate_series(1,100) s(i);
insert into t select i
, (1 + mod(i, 100))
from generate_series(1, 100000) g(i);
create index on t(d1);
