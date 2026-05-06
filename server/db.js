const mysql = require('mysql2/promise');

const pool = mysql.createPool({
  host: 'localhost',
  user: 'root',
  password: '0656',
  database: 'naengjibsa',
  charset: 'utf8mb4',
  waitForConnections: true,
  connectionLimit: 10,
});

module.exports = pool;