
select * from project.dict_employees
select * from project.dict_position_in
select * from project.dict_city
select * from project.dict_locate
select * from project.dwh_commit
select * from project.HIST_commit





create table project.dict_employees --Справочник сотрудников
(
	id bigserial primary key,
	name text not null,
	start_date timestamp,
	end_date timestamp,
	is_active bool default true,
	created_dttm timestamp default current_timestamp, -- Дата и время создание записи
	created_user text default 'вручную'-- Кто создал	
);

create or replace function project.add_dict_employees -- функция нанимает человека на id должности
 (
	p_name text,
	p_pos int8
 )
 returns void
 language plpgsql
 as $$
declare p_em int8;
begin
 		insert into project.dict_employees (name, start_date)
 		values (p_name, current_timestamp)
			returning id into p_em;
		insert into project.map_em2pos (pos, em)
		values (p_pos, p_em);
 	return;
end;
$$;

create table project.dict_position --- Справочник должностей
(
	id bigserial primary key,
	position text not null,
	is_active bool default true,
	created_dttm timestamp default current_timestamp, -- Дата и время создание записи
	created_user text default 'вручную'-- Кто создал
);


create table project.map_em2pos --- Маппер сотрудник на должность
(
	id bigserial primary key,
	em int8,
	pos int8,
	start_date timestamp default current_timestamp,
	end_date timestamp,
	created_dttm timestamp default current_timestamp, -- Дата и время создание записи
	created_user text default 'вручную',-- Кто создал
	constraint em2pos foreign key (em) references project.dict_employees (id),
	constraint pos2em foreign key (pos) references project.dict_position (id)
);


create table project.dict_city ---- Справочник городов
(
	id bigserial primary key,
	city varchar (250),
	is_active bool default true,
	created_dttm timestamp default current_timestamp, -- Дата и время создание записи
	created_user text default 'вручную'-- Кто создал
);


create table project.dict_locate
--Справочник объектов с местом стройки, координатами центра, краткое описание ТЗ на строительство, стоимость объекта, с сылкой на город
(
	id bigserial primary key,
	facility varchar (250),
	coord_x numeric,
	coord_y numeric,
	accord_to text,
	amount numeric,
	id_locate int8,
	is_active bool default true,
	created_dttm timestamp default current_timestamp, -- Дата и время создание записи
	created_user text default 'вручную',-- Кто создал
	constraint id_locate2id_city foreign key (id_locate) references project.dict_city(id)
);

create or replace function project.add_dict_locate /* функция добавляет строительныхй объект, добавляе наименование строительного объекта, координаты Х, Координаты У, 
краткое описание ТЗ на строительство, стоимость строительства, ссылку на ID города строительства*/
  (
	p_facility varchar (250),
	p_coord_x numeric,
	p_coord_y numeric,
	p_accord_to text,
	p_amount numeric,
	p_id_locate int8
 )
 returns void
 language plpgsql
 as $$
begin
 		insert into project.dict_locate (facility, coord_x, coord_y, accord_to, amount, id_locate)
 		values (p_facility, p_coord_x, p_coord_y, p_accord_to, p_amount, p_id_locate);
 	return;
end;
$$;


create table project.dict_position_in-- Справочник должности внутри одного проекта (объекта)
(
	id bigserial primary key,
	position text not null,
	id_locate int8,
	start_date timestamp,
	end_date timestamp,
	is_active bool default true,
	created_dttm timestamp default current_timestamp, -- Дата и время создание записи
	created_user text default 'вручную',-- Кто создал
	constraint id_position2id_locate foreign key (id_locate) references project.dict_locate (id)
);


create table project.map_em2loc2pi-- Маппер сотрудника на объект и статус, кто он в этом проекте, доля с проекта
(
	id bigserial primary key,
	id_name int8, --сотрудник 
	id_locate int8, --на объекте 
	id_position_in int8, --и его статус, кто он в этом проекте
	amount numeric,  --доля с проекта
	start_date timestamp,
	end_date timestamp,
	created_dttm timestamp default current_timestamp, -- Дата и время создание записи
	created_user text default 'вручную',-- Кто создал
	constraint em2id_name foreign key (id_name) references project.dict_employees (id),
	constraint em2id_locate foreign key (id_locate) references project.dict_locate (id),
	constraint em2id_position_in foreign key (id_position_in) references project.dict_position_in (id)
);

create or replace function project.add_map_em2loc2pi -- функция нанимает человека на объект, прописывая его должность, указывая зарплату
 (
 	p_position_in text,
	p_id_name int8,
	p_id_locate int8,
	p_amount numeric
 )
 returns void
 language plpgsql
 as $$
declare a_id_position_in int;
begin
		insert into project.dict_position_in (position, id_locate, start_date)
		values (p_position_in, p_id_locate, current_timestamp)
	returning id into a_id_position_in;
		insert into project.map_em2loc2pi(id_name,id_locate, amount, id_position_in,start_date)
		values (p_id_name,p_id_locate, p_amount, a_id_position_in,current_timestamp);
	return;
end;
$$;

create table project.dwh_commit-- DWH комментариев к объекту (Типо сообщений) с возможностью отжатия решено или нет. При том 2 колонки - 1 для комментатора, 2 для проектировщика
(
	id bigserial primary key,
	locate_id int8,
	created_dttm timestamptz default current_timestamp, -- Дата и время создание записи
	created_user text default 'ВРУЧНУЮ', -- Кто создал 
	is_complete bool default false,--с возможностью отжатия решено или нет
	comment_user text, -- комментарий пользователя к объекту
	comment_designer text, -- комментарий проектировщика к объекту
	update_dttm timestamptz default current_timestamp, -- Дата и время измения записи
	update_user text default 'вручную', -- Как изменили записи 
	constraint id_locate2dwh_commit foreign key (locate_id) references project.dict_locate(id)
);

create or replace function project.add_dwh_commit -- функция добавляет комментарии пользователя, комментарии проектировщика к объекту, выдает решения true/false, в конце нужно указать автора
 (
	p_comment_user text,
	p_comment_designer text,
	p_locate_id int8,
	p_is_complete bool	
 )
 returns void
 language plpgsql
 as $$
	declare p_id_dwh_commit int8; 
begin
 		insert into project.dwh_commit (comment_user, comment_designer, locate_id, is_complete, created_dttm)
 		values (p_comment_user, p_comment_designer, p_locate_id, p_is_complete, current_timestamp)
			returning id into p_id_dwh_commit;
		insert into project.HIST_commit (id_dwh_commit, id_locate, created_dttm)
		values (p_id_dwh_commit, p_locate_id, current_timestamp);
 	return;
end;
$$;


create or replace function project.update_dwh_commit -- функция обновляет по id_dwh комментарии пользователя к объекту, выдает решения true/false
 (
	p_id_dwh_commit int8,
	p_comment_user text,
	p_is_complete bool
 )
 returns void
 language plpgsql
 as $$
	declare p_locate_id int := (select locate_id from project.dwh_commit where id = p_id_dwh_commit);
	begin
 		update project.dwh_commit
 		set comment_user = p_comment_user, is_complete = p_is_complete
		where id = p_id_dwh_commit;
		insert into project.HIST_commit (id_dwh_commit, id_locate, created_dttm) 
		values (p_id_dwh_commit, p_locate_id, current_timestamp);
 	return;
end;
$$;

create table project.HIST_commit-- HIST таблица комментариев. При изменении комментария его копия сохраняется в эту таблицу 
(
	id_dwh_commit int8,
	id_locate int8,
	created_dttm timestamptz default current_timestamp, -- Дата и время создание записи
	created_user text default 'вручную', -- Кто создал 
	update_dttm timestamptz default current_timestamp, -- Дата и время изменил записи
	update_user text default '', -- Кто изменил записи
	constraint id_dwh_commit2HIST_commit foreign key (id_dwh_commit) references project.dwh_commit (id),
	constraint id_locate2HIST_commit foreign key (id_locate) references project.dict_locate (id)
);

select  
	hc.id_dwh_commit, 
	dc.is_complete 
from project.HIST_commit hc 
left join project.dwh_commit dc 
		on hc.id_dwh_commit = dc.id 
		
