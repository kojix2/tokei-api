-- PostgreSQLの初期化スクリプト

-- 拡張機能の有効化
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- 注意: テーブルとインデックスの作成はアプリケーション側で行うため、ここでは行いません
-- アプリケーションの起動時にsrc/config/database.crのsetupメソッドで作成されます
