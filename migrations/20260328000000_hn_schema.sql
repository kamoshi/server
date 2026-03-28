CREATE TABLE hn_stories (
    id INTEGER PRIMARY KEY,              -- HN story ID (objectID from Algolia)
    title TEXT NOT NULL,
    url TEXT,                             -- nullable, some stories are Ask HN etc.
    author TEXT NOT NULL,
    points INTEGER NOT NULL DEFAULT 0,
    num_comments INTEGER NOT NULL DEFAULT 0,
    created_at INTEGER NOT NULL,          -- unix timestamp from HN
    fetched_at TEXT NOT NULL DEFAULT (datetime('now'))
);

CREATE TABLE hn_ratings (
    story_id INTEGER PRIMARY KEY REFERENCES hn_stories(id),
    rating TEXT NOT NULL CHECK (rating IN ('thumbs_up', 'average', 'thumbs_down')),
    rated_at TEXT NOT NULL DEFAULT (datetime('now'))
);