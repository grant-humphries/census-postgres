--This script adds a truncated geoid (removes all characters from 'US' moving
--left, inclusive).  This form of the geoid is what is provided in the tiger
--data and will also joining to those geographies.  Note that this field is
--being left null where it is not distinct within the geoheader table, this
--is into ensure incorrect matches are not made.

drop table if exists dst_trunc_geoid cascade;
create temp table dst_trunc_geoid as
  select regexp_replace(geoid, '.*US', '') as t_geoid
  from acs2013_5yr.geoheader
  group by t_geoid
  having count(*) < 2;

alter table acs2013_5yr.geoheader
  drop column if exists trunc_geoid cascade; 
alter table acs2013_5yr.geoheader add trunc_geoid text;

update acs2013_5yr.geoheader as gh set trunc_geoid = 
  case when exists (
    select null from dst_trunc_geoid tg
    where tg.t_geoid = regexp_replace(gh.geoid, '.*US', ''))
  then regexp_replace(geoid, '.*US', '')
  else null end;

create index geoheader_t_geoid_ix on acs2013_5yr.geoheader 
  using btree (trunc_geoid);

drop table dst_trunc_geoid;