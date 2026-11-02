-- Enable Realtime for these tables
alter publication supabase_realtime add table matches;
alter publication supabase_realtime add table match_participants;

-- 1. Table: matchmaking_queue
create table matchmaking_queue (
  id uuid default gen_random_uuid() primary key,
  user_id uuid references auth.users not null unique,
  app_version text not null,
  created_at timestamp with time zone default timezone('utc'::text, now()) not null,
  score int default 0
);

-- 2. Table: matches
create table matches (
  id uuid default gen_random_uuid() primary key,
  player1_id uuid references auth.users not null,
  player2_id uuid references auth.users not null,
  status text check (status in ('waiting', 'active', 'finished')) default 'active',
  winner_id uuid references auth.users,
  seed bigint not null, -- Random seed for deterministic question selection
  created_at timestamp with time zone default timezone('utc'::text, now()) not null
);

-- 3. Table: match_participants
create table match_participants (
  id uuid default gen_random_uuid() primary key,
  match_id uuid references matches on delete cascade not null,
  user_id uuid references auth.users not null,
  current_score int default 0,
  current_question_index int default 0,
  finished_at timestamp with time zone,
  created_at timestamp with time zone default timezone('utc'::text, now()) not null,
  unique(match_id, user_id)
);

-- RLS Policies
alter table matchmaking_queue enable row level security;
alter table matches enable row level security;
alter table match_participants enable row level security;

-- Queue policies
create policy "Users can insert themselves" on matchmaking_queue for insert with check (auth.uid() = user_id);
create policy "Users can delete themselves" on matchmaking_queue for delete using (auth.uid() = user_id);

-- Matches policies
create policy "Users can see their matches" on matches for select using (auth.uid() = player1_id or auth.uid() = player2_id);
create policy "System creates matches" on matches for insert with check (true);

-- Participants policies
create policy "Users can see participants in their match" on match_participants for select using (
  exists (
    select 1 from matches m 
    where m.id = match_participants.match_id 
    and (m.player1_id = auth.uid() or m.player2_id = auth.uid())
  )
);
create policy "Users can update their own progress" on match_participants for update using (auth.uid() = user_id);

-- 4. Atomic Matchmaking Function
create or replace function find_or_create_match(p_user_id uuid, p_app_version text)
returns table (match_id uuid, player1_id uuid, player2_id uuid, seed bigint)
language plpgsql
security definer
as $$
declare
  waiting_user_id uuid;
  new_match_id uuid;
  random_seed bigint;
begin
  -- 1. Try to find a waiting user (Locking the row)
  delete from matchmaking_queue
  where id = (
    select id from matchmaking_queue
    where user_id != p_user_id
    and app_version = p_app_version
    order by created_at asc
    limit 1
    for update skip locked
  )
  returning user_id into waiting_user_id;

  -- 2. If we found someone
  if waiting_user_id is not null then
    -- Generate a big random seed
    random_seed := floor(random() * 2147483647)::bigint;

    -- Create the match
    insert into matches (player1_id, player2_id, seed, status)
    values (waiting_user_id, p_user_id, random_seed, 'active')
    returning id into new_match_id;

    -- Initialize participants
    insert into match_participants (match_id, user_id) values (new_match_id, waiting_user_id);
    insert into match_participants (match_id, user_id) values (new_match_id, p_user_id);

    return query select new_match_id, waiting_user_id, p_user_id, random_seed;
  
  else
    -- 3. No one found, add self to queue
    insert into matchmaking_queue (user_id, app_version)
    values (p_user_id, p_app_version)
    on conflict (user_id) do nothing;
    
    return; -- Return nothing (waiting)
  end if;
end;
$$;
