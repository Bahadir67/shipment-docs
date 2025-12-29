-- MVP database schema (PostgreSQL)

CREATE TABLE users (
  id uuid PRIMARY KEY,
  username text UNIQUE NOT NULL,
  email text,
  role text NOT NULL DEFAULT 'user',
  password_hash text NOT NULL,
  password_salt text NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE products (
  id uuid PRIMARY KEY,
  serial text UNIQUE NOT NULL,
  customer text NOT NULL,
  project text NOT NULL,
  product_type text,
  year int NOT NULL,
  onedrive_folder_id text,
  status text NOT NULL DEFAULT 'open',
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE files (
  id uuid PRIMARY KEY,
  product_id uuid REFERENCES products(id),
  type text NOT NULL,
  category text,
  file_id text NOT NULL,
  file_url text,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE view_logs (
  id uuid PRIMARY KEY,
  user_id uuid REFERENCES users(id),
  product_id text,
  file_id text,
  action text NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now()
);
