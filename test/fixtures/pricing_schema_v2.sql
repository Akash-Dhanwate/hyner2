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

CREATE TABLE pricing_rate_card_versions (
  business_id TEXT NOT NULL,
  profile_id TEXT NOT NULL,
  version INTEGER NOT NULL CHECK (version > 0),
  effective_at INTEGER NOT NULL,
  expires_at INTEGER,
  published_at INTEGER NOT NULL,
  published_by TEXT NOT NULL,
  snapshot_json TEXT NOT NULL,
  sealed INTEGER NOT NULL DEFAULT 0 CHECK (sealed IN (0, 1)),
  PRIMARY KEY (business_id, profile_id, version),
  FOREIGN KEY (business_id, profile_id) REFERENCES pricing_profiles (business_id, id),
  CHECK (expires_at IS NULL OR expires_at > effective_at)
);

CREATE INDEX pricing_effective_idx ON pricing_rate_card_versions (business_id, profile_id, effective_at DESC, version DESC);

CREATE TABLE pricing_categories (
  business_id TEXT NOT NULL,
  profile_id TEXT NOT NULL,
  version INTEGER NOT NULL,
  id TEXT NOT NULL,
  parent_id TEXT,
  name TEXT NOT NULL,
  sort_order INTEGER NOT NULL,
  snapshot_json TEXT NOT NULL,
  PRIMARY KEY (business_id, profile_id, version, id),
  FOREIGN KEY (business_id, profile_id, version) REFERENCES pricing_rate_card_versions (business_id, profile_id, version),
  FOREIGN KEY (business_id, profile_id, version, parent_id) REFERENCES pricing_categories (business_id, profile_id, version, id) DEFERRABLE INITIALLY DEFERRED
);

CREATE TABLE pricing_variants (
  business_id TEXT NOT NULL,
  profile_id TEXT NOT NULL,
  version INTEGER NOT NULL,
  id TEXT NOT NULL,
  category_id TEXT NOT NULL,
  snapshot_json TEXT NOT NULL,
  PRIMARY KEY (business_id, profile_id, version, id),
  UNIQUE (business_id, profile_id, version, category_id, id),
  FOREIGN KEY (business_id, profile_id, version, category_id) REFERENCES pricing_categories (business_id, profile_id, version, id)
);

CREATE TABLE pricing_rule_versions (
  business_id TEXT NOT NULL,
  profile_id TEXT NOT NULL,
  version INTEGER NOT NULL,
  id TEXT NOT NULL,
  category_id TEXT NOT NULL,
  variant_id TEXT,
  pricing_method TEXT NOT NULL,
  rate_decimal TEXT NOT NULL,
  snapshot_json TEXT NOT NULL,
  PRIMARY KEY (business_id, profile_id, version, id),
  FOREIGN KEY (business_id, profile_id, version, category_id) REFERENCES pricing_categories (business_id, profile_id, version, id),
  FOREIGN KEY (business_id, profile_id, version, category_id, variant_id) REFERENCES pricing_variants (business_id, profile_id, version, category_id, id)
);

CREATE UNIQUE INDEX pricing_rule_target_idx ON pricing_rule_versions (business_id, profile_id, version, category_id, IFNULL(variant_id, ''));

CREATE TABLE pricing_addons (
  business_id TEXT NOT NULL,
  profile_id TEXT NOT NULL,
  version INTEGER NOT NULL,
  id TEXT NOT NULL,
  name TEXT NOT NULL,
  snapshot_json TEXT NOT NULL,
  PRIMARY KEY (business_id, profile_id, version, id),
  FOREIGN KEY (business_id, profile_id, version) REFERENCES pricing_rate_card_versions (business_id, profile_id, version)
);

CREATE TABLE pricing_rule_addons (
  business_id TEXT NOT NULL,
  profile_id TEXT NOT NULL,
  version INTEGER NOT NULL,
  rule_id TEXT NOT NULL,
  addon_id TEXT NOT NULL,
  PRIMARY KEY (business_id, profile_id, version, rule_id, addon_id),
  FOREIGN KEY (business_id, profile_id, version, rule_id) REFERENCES pricing_rule_versions (business_id, profile_id, version, id),
  FOREIGN KEY (business_id, profile_id, version, addon_id) REFERENCES pricing_addons (business_id, profile_id, version, id)
);

CREATE TABLE pricing_audit_events (
  id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
  business_id TEXT NOT NULL,
  actor_uid TEXT NOT NULL,
  "action" TEXT NOT NULL,
  profile_id TEXT NOT NULL,
  before_snapshot TEXT,
  after_snapshot TEXT NOT NULL,
  created_at INTEGER NOT NULL,
  FOREIGN KEY (business_id, profile_id) REFERENCES pricing_profiles (business_id, id)
);

CREATE INDEX pricing_audit_business_idx ON pricing_audit_events (business_id, profile_id, id DESC);

PRAGMA user_version = 2;
