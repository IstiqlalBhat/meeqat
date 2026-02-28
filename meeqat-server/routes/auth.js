const express = require('express');
const bcrypt = require('bcrypt');
const { supabase } = require('../db/supabase');

const router = express.Router();

router.get('/login', (req, res) => {
  if (req.session && req.session.authenticated) {
    return res.redirect('/admin');
  }
  res.render('login', { error: null });
});

router.post('/login', async (req, res) => {
  const { password } = req.body;

  try {
    const { data: admin } = await supabase
      .from('admin_settings')
      .select('password_hash')
      .limit(1)
      .single();

    if (admin && bcrypt.compareSync(password, admin.password_hash)) {
      req.session.authenticated = true;
      return res.redirect('/admin');
    }
  } catch (err) {
    console.error('Login error:', err.message);
  }

  res.render('login', { error: 'Invalid password' });
});

router.get('/logout', (req, res) => {
  req.session.destroy(() => {
    res.redirect('/admin/login');
  });
});

module.exports = router;
