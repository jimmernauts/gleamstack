-- migrate:up

create table recipes (
    id text primary key,
    slug text not null,
    title text not null,
    cook_time integer not null,
    prep_time integer not null,
    serves integer not null,
    author text,
    source text,
    ingredients json,
    method_steps json,
    tags json,
    shortlisted boolean
);

create table tag_options (
    id text primary key,
    name text,
    options json
);

create table plans (
    id text primary key,
    date integer not null,
    planned_meals json
);

-- migrate:down

drop table recipes;
drop table tag_options;
drop table plans;