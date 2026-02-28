require('dotenv').config();

const express = require('express');
const cookieSession = require('cookie-session');
const cors = require('cors');
const path = require('path');

const app = express();
const PORT = process.env.PORT || 3000;

// View engine
app.set('view engine', 'ejs');
app.set('views', path.join(__dirname, 'views'));

// Middleware
app.use(cors({
  origin: '*',
  methods: ['GET', 'POST', 'PUT', 'DELETE', 'OPTIONS'],
  allowedHeaders: ['Content-Type', 'Authorization']
}));
app.use(express.urlencoded({ extended: true }));
app.use(express.json());
app.use(express.static(path.join(__dirname, 'public')));

app.use(cookieSession({
  name: 'meeqat_session',
  keys: [process.env.SESSION_SECRET || 'meeqat-prayer-times-secret-key'],
  maxAge: 7 * 24 * 60 * 60 * 1000, // 7 days
  secure: process.env.NODE_ENV === 'production',
  sameSite: 'lax'
}));

// Flash messages middleware
app.use((req, res, next) => {
  res.locals.flash = req.session.flash || {};
  delete req.session.flash;
  next();
});

// Routes
const apiRoutes = require('./routes/api');
const adminRoutes = require('./routes/admin');
const authRoutes = require('./routes/auth');

app.use('/api', apiRoutes);
app.use('/admin', authRoutes);
app.use('/admin', adminRoutes);

// Root redirect
app.get('/', (req, res) => {
  res.redirect('/admin');
});

// Health check for Vercel
app.get('/health', (req, res) => {
  res.json({ status: 'ok', timestamp: new Date().toISOString() });
});

// Only listen when not in serverless mode
if (process.env.VERCEL !== '1') {
  app.listen(PORT, () => {
    console.log(`Meeqat server running at http://localhost:${PORT}`);
    console.log(`Admin dashboard: http://localhost:${PORT}/admin`);
    console.log(`API: http://localhost:${PORT}/api/masjids`);
  });
}

module.exports = app;
