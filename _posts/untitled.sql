CREATE TABLE `user_permissions` (
	`user_id`	TEXT,
	`age` INTEGER DEFAULT 0,
	`gender` INTEGER DEFAULT 0,
	`education` INTEGER DEFAULT 0,
	`occupation` INTEGER DEFAULT 0,
	`marital.status` INTEGER DEFAULT 0,
	`no.of.adults` INTEGER DEFAULT 0,
	`no.of.children` INTEGER DEFAULT 0,
	`web.history` INTEGER DEFAULT 0,
	`location` INTEGER DEFAULT 0,
	`mobile.apps.usage` INTEGER DEFAULT 0,
	`phone.model` INTEGER DEFAULT 0,
	`street` INTEGER DEFAULT 0,
	`city` INTEGER DEFAULT 0,
	`state` INTEGER DEFAULT 0,
	`rent.own` INTEGER DEFAULT 0,
	`apart.house` INTEGER DEFAULT 0,
	`residency` INTEGER DEFAULT 0,
	`income.range` INTEGER DEFAULT 0,
	`cred.card.use` INTEGER DEFAULT 0,
	`cred.card.type` INTEGER DEFAULT 0,
	`cred.card.freq` INTEGER DEFAULT 0,
	`cash.purchase` INTEGER DEFAULT 0,
	`ethnicity` INTEGER DEFAULT 0,
	`pol.opnion` INTEGER DEFAULT 0,
	`rel.opinion` INTEGER DEFAULT 0,
	`trade.union.mem` INTEGER DEFAULT 0,
	`health.data` INTEGER DEFAULT 0,
	`sexual.data` INTEGER DEFAULT 0,
	`p.vehicle.year` INTEGER DEFAULT 0,
	`p.vehicle.make` INTEGER DEFAULT 0,
	`p.vehicle.model` INTEGER DEFAULT 0,
	`s.vehicle.year` INTEGER DEFAULT 0,
	`s.vehicle.make` INTEGER DEFAULT 0,
	`s.vehicle.model` INTEGER DEFAULT 0,
	`vehicle.intent` INTEGER DEFAULT 0,
	`online.shopping.history` INTEGER DEFAULT 0,
	PRIMARY KEY(`user_id`)
);

CREATE TABLE `user_permissions` (
	user_id TEXT,
	permission INTEGER,
	UNIQUE(user_id, permission)
);

CREATE INDEX user_permission_idx 
ON user_permissions (user_id, permission);