CREATE TABLE pricing_profiles (
  business_id TEXT NOT NULL,
  id TEXT NOT NULL,
  name TEXT NOT NULL,
  status TEXT NOT NULL DEFAULT 'draft' CHECK (status IN ('draft', 'published', 'archived')),
  created_at INTEGER NOT NULL,
  updated_at INTEGER NOT NULL,
  PRIMARY KEY (business_id, id)
);
CREATE TABLE pricing_drafts (
  business_id TEXT NOT NULL,
  profile_id TEXT NOT NULL,
  revision INTEGER NOT NULL CHECK (revision > 0),
  snapshot_json TEXT NOT NULL,
  PRIMARY KEY (business_id, profile_id),
  FOREIGN KEY (business_id, profile_id) REFERENCES pricing_profiles (business_id, id)
);
PRAGMA user_version = 1;
