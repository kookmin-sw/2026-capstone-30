const mysql = require('mysql2/promise');

const pool = mysql.createPool({
  host: process.env.MYSQLHOST || 'localhost',
  user: process.env.MYSQLUSER || 'root',
  password: process.env.MYSQLPASSWORD || '0656',
  database: process.env.MYSQLDATABASE || 'naengjibsa',
  port: process.env.MYSQLPORT || 3306,
  charset: 'utf8mb4',
  waitForConnections: true,
  connectionLimit: 10,
  connectTimeout: 10000,
  enableKeepAlive: true,
  keepAliveInitialDelay: 0,
});

module.exports = pool;