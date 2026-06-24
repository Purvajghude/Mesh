create table collab_pitches (
  id          uuid        primary key default gen_random_uuid(),
  match_id    uuid        not null references matches(id) on delete cascade,
  user_a_id   uuid        not null,
  user_b_id   uuid        not null,
  pitches     jsonb       not null,
  created_at  timestamptz default now()
);

create index on collab_pitches(match_id, created_at desc);
