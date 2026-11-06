-- 초기 설치용. 기존 tasks 테이블이 있다면 별도 마이그레이션이 필요합니다.
begin;
create table public.tasks (
 id uuid primary key default gen_random_uuid(),
 user_id uuid not null references auth.users(id) on delete cascade,
 title text not null check (char_length(btrim(title)) between 1 and 150),
 description text not null default '' check (char_length(description)<=5000),
 status text not null default 'todo' check (status in ('todo','doing','done')),
 priority text not null default 'medium' check (priority in ('low','medium','high')),
 due date check (due is null or due between date '1900-01-01' and date '9999-12-31'),
 created_at timestamptz not null default now(),
 updated_at timestamptz not null default now()
);
create index tasks_user_updated_idx on public.tasks(user_id,updated_at desc,id desc);
create function public.touch_task_updated_at() returns trigger language plpgsql set search_path = '' as $$
begin
 new.updated_at := clock_timestamp();
 new.created_at := old.created_at;
 return new;
end;
$$;
create trigger tasks_updated before update on public.tasks for each row execute function public.touch_task_updated_at();
alter table public.tasks enable row level security;
revoke all on public.tasks from anon;
grant select,insert,update,delete on public.tasks to authenticated;
create policy tasks_select on public.tasks for select to authenticated using ((select auth.uid())=user_id);
create policy tasks_insert on public.tasks for insert to authenticated with check ((select auth.uid())=user_id);
create policy tasks_update on public.tasks for update to authenticated using ((select auth.uid())=user_id) with check ((select auth.uid())=user_id);
create policy tasks_delete on public.tasks for delete to authenticated using ((select auth.uid())=user_id);
-- 호출 사용자의 RLS 적용. 삭제와 삽입은 하나의 트랜잭션으로 실행.
create function public.replace_my_tasks(items jsonb) returns void language plpgsql security invoker set search_path = '' as $$
begin
 if auth.uid() is null then raise exception 'Authentication required'; end if;
 if items is null or jsonb_typeof(items) <> 'array' then raise exception 'Array required'; end if;
 if jsonb_array_length(items)>10000 then raise exception 'Maximum 10000 tasks'; end if;
 -- 복원 시 다른 탭의 일반 CRUD 작업을 중단하세요.
 perform pg_advisory_xact_lock(hashtextextended(auth.uid()::text,0));
 delete from public.tasks where user_id=auth.uid();
 insert into public.tasks(user_id,title,description,status,priority,due)
 select auth.uid(),x.title,x.description,x.status,x.priority,nullif(x.due,'')::date
 from jsonb_to_recordset(items) as x(title text,description text,status text,priority text,due text);
end;
$$;
revoke all on function public.replace_my_tasks(jsonb) from public,anon;
grant execute on function public.replace_my_tasks(jsonb) to authenticated;
commit;
