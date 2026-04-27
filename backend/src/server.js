const express = require('express');
const cors = require('cors');
const fs = require('fs/promises');
const path = require('path');
const sqlite3 = require('sqlite3').verbose();

const app = express();
const PORT = process.env.PORT || 3000;

const dataDir = path.join(__dirname, '..', 'data');
const profilePath = path.join(dataDir, 'profile.json');
const expensesPath = path.join(dataDir, 'expenses.json');
const dbPath = path.join(dataDir, 'app.db');

app.use(cors());
app.use(express.json());

const db = new sqlite3.Database(dbPath);

function run(sql, params = []) {
  return new Promise((resolve, reject) => {
    db.run(sql, params, function onResult(error) {
      if (error) {
        reject(error);
        return;
      }
      resolve({ id: this.lastID, changes: this.changes });
    });
  });
}

function all(sql, params = []) {
  return new Promise((resolve, reject) => {
    db.all(sql, params, (error, rows) => {
      if (error) {
        reject(error);
        return;
      }
      resolve(rows);
    });
  });
}

async function ensureJson(filePath, defaultValue) {
  try {
    await fs.access(filePath);
  } catch {
    await fs.writeFile(filePath, JSON.stringify(defaultValue, null, 2));
  }
}

async function readProfileDocument() {
  const content = await fs.readFile(profilePath, 'utf-8');
  const parsed = JSON.parse(content);

  if (Array.isArray(parsed)) {
    return parsed;
  }

  if (parsed && typeof parsed === 'object' && 'profiles' in parsed) {
    return Array.isArray(parsed.profiles) ? parsed.profiles : [];
  }

  if (parsed && typeof parsed === 'object' && 'current' in parsed) {
    return {
      current: parsed.current || { name: '', email: '' },
      history: Array.isArray(parsed.history) ? parsed.history : [],
    };
  }

  return [];
}

async function writeProfileDocument(document) {
  await fs.writeFile(profilePath, JSON.stringify(document, null, 2));
}

function normalizeProfilesDocument(document) {
  if (Array.isArray(document)) {
    return document;
  }

  if (document && typeof document === 'object' && 'profiles' in document) {
    return Array.isArray(document.profiles) ? document.profiles : [];
  }

  if (document && typeof document === 'object' && 'history' in document) {
    return Array.isArray(document.history)
      ? document.history.map((item) => ({
          id: item.id || Date.now(),
          name: item.name || '',
          email: item.email || '',
          createdAt: item.createdAt || new Date().toISOString(),
        }))
      : [];
  }

  if (document && typeof document === 'object') {
    const name = String(document.name || '');
    const email = String(document.email || '');
    return name || email
      ? [
          {
            id: Date.now(),
            name,
            email,
            createdAt: new Date().toISOString(),
          },
        ]
      : [];
  }

  return [];
}

async function setup() {
  await fs.mkdir(dataDir, { recursive: true });
  await ensureJson(profilePath, []);
  await ensureJson(expensesPath, []);

  await run(
    `CREATE TABLE IF NOT EXISTS attendance (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      name TEXT NOT NULL,
      created_at TEXT DEFAULT CURRENT_TIMESTAMP
    )`
  );

  await run(
    `CREATE TABLE IF NOT EXISTS inventory (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      name TEXT NOT NULL,
      quantity INTEGER NOT NULL,
      created_at TEXT DEFAULT CURRENT_TIMESTAMP
    )`
  );
}

app.get('/api/profile', async (req, res) => {
  try {
    const profiles = normalizeProfilesDocument(await readProfileDocument());
    res.json(profiles[0] || { name: '', email: '' });
  } catch (error) {
    res.status(500).json({ message: 'Erro ao carregar perfil', details: error.message });
  }
});

app.get('/api/profiles', async (req, res) => {
  try {
    const profiles = normalizeProfilesDocument(await readProfileDocument());
    res.json(profiles);
  } catch (error) {
    res.status(500).json({ message: 'Erro ao carregar perfis', details: error.message });
  }
});

app.post('/api/profiles', async (req, res) => {
  const name = String(req.body.name || '').trim();
  const email = String(req.body.email || '').trim();

  if (!name || !email) {
    res.status(400).json({ message: 'Nome e e-mail sao obrigatorios' });
    return;
  }

  try {
    const profiles = normalizeProfilesDocument(await readProfileDocument());
    const profile = {
      id: Date.now(),
      name,
      email,
      createdAt: new Date().toISOString(),
    };
    const nextProfiles = [profile, ...profiles];
    await writeProfileDocument(nextProfiles);
    res.status(201).json(profile);
  } catch (error) {
    res.status(500).json({ message: 'Erro ao salvar perfil', details: error.message });
  }
});

app.put('/api/profiles/:id', async (req, res) => {
  const id = Number(req.params.id);
  const name = String(req.body.name || '').trim();
  const email = String(req.body.email || '').trim();

  if (!Number.isFinite(id) || !name || !email) {
    res.status(400).json({ message: 'Id, nome e e-mail sao obrigatorios' });
    return;
  }

  try {
    const profiles = normalizeProfilesDocument(await readProfileDocument());
    const index = profiles.findIndex((item) => item.id === id);

    if (index === -1) {
      res.status(404).json({ message: 'Perfil nao encontrado' });
      return;
    }

    profiles[index] = {
      ...profiles[index],
      name,
      email,
    };

    await writeProfileDocument(profiles);
    res.json(profiles[index]);
  } catch (error) {
    res.status(500).json({ message: 'Erro ao atualizar perfil', details: error.message });
  }
});

app.delete('/api/profiles/:id', async (req, res) => {
  const id = Number(req.params.id);

  try {
    const profiles = normalizeProfilesDocument(await readProfileDocument());
    const nextProfiles = profiles.filter((item) => item.id !== id);

    if (nextProfiles.length === profiles.length) {
      res.status(404).json({ message: 'Perfil nao encontrado' });
      return;
    }

    await writeProfileDocument(nextProfiles);
    res.status(204).send();
  } catch (error) {
    res.status(500).json({ message: 'Erro ao excluir perfil', details: error.message });
  }
});

app.get('/api/expenses', async (req, res) => {
  try {
    const content = await fs.readFile(expensesPath, 'utf-8');
    res.json(JSON.parse(content));
  } catch (error) {
    res.status(500).json({ message: 'Erro ao carregar despesas', details: error.message });
  }
});

app.post('/api/expenses', async (req, res) => {
  const description = String(req.body.description || '').trim();
  const amount = Number(req.body.amount);

  if (!description || Number.isNaN(amount) || amount <= 0) {
    res.status(400).json({ message: 'Descricao e valor valido sao obrigatorios' });
    return;
  }

  try {
    const content = await fs.readFile(expensesPath, 'utf-8');
    const items = JSON.parse(content);
    const expense = {
      id: Date.now(),
      description,
      amount,
      createdAt: new Date().toISOString(),
    };

    items.push(expense);
    await fs.writeFile(expensesPath, JSON.stringify(items, null, 2));
    res.status(201).json(expense);
  } catch (error) {
    res.status(500).json({ message: 'Erro ao salvar despesa', details: error.message });
  }
});

app.put('/api/expenses/:id', async (req, res) => {
  const id = Number(req.params.id);
  const description = String(req.body.description || '').trim();
  const amount = Number(req.body.amount);

  if (!Number.isFinite(id) || !description || Number.isNaN(amount) || amount <= 0) {
    res.status(400).json({ message: 'Id, descricao e valor valido sao obrigatorios' });
    return;
  }

  try {
    const content = await fs.readFile(expensesPath, 'utf-8');
    const items = JSON.parse(content);
    const index = items.findIndex((item) => item.id === id);

    if (index === -1) {
      res.status(404).json({ message: 'Despesa nao encontrada' });
      return;
    }

    items[index] = {
      ...items[index],
      description,
      amount,
    };

    await fs.writeFile(expensesPath, JSON.stringify(items, null, 2));
    res.json(items[index]);
  } catch (error) {
    res.status(500).json({ message: 'Erro ao atualizar despesa', details: error.message });
  }
});

app.delete('/api/expenses/:id', async (req, res) => {
  const id = Number(req.params.id);

  try {
    const content = await fs.readFile(expensesPath, 'utf-8');
    const items = JSON.parse(content);
    const nextItems = items.filter((item) => item.id !== id);

    if (nextItems.length === items.length) {
      res.status(404).json({ message: 'Despesa nao encontrada' });
      return;
    }

    await fs.writeFile(expensesPath, JSON.stringify(nextItems, null, 2));
    res.status(204).send();
  } catch (error) {
    res.status(500).json({ message: 'Erro ao excluir despesa', details: error.message });
  }
});

app.get('/api/attendance', async (req, res) => {
  try {
    const rows = await all('SELECT id, name, created_at AS createdAt FROM attendance ORDER BY id DESC');
    res.json(rows);
  } catch (error) {
    res.status(500).json({ message: 'Erro ao carregar frequencia', details: error.message });
  }
});

app.post('/api/attendance', async (req, res) => {
  const name = String(req.body.name || '').trim();

  if (!name) {
    res.status(400).json({ message: 'Nome e obrigatorio' });
    return;
  }

  try {
    const result = await run('INSERT INTO attendance (name) VALUES (?)', [name]);
    const rows = await all('SELECT id, name, created_at AS createdAt FROM attendance WHERE id = ?', [result.id]);
    res.status(201).json(rows[0]);
  } catch (error) {
    res.status(500).json({ message: 'Erro ao salvar frequencia', details: error.message });
  }
});

app.put('/api/attendance/:id', async (req, res) => {
  const id = Number(req.params.id);
  const name = String(req.body.name || '').trim();

  if (!Number.isFinite(id) || !name) {
    res.status(400).json({ message: 'Id e nome sao obrigatorios' });
    return;
  }

  try {
    const result = await run('UPDATE attendance SET name = ? WHERE id = ?', [name, id]);

    if (result.changes === 0) {
      res.status(404).json({ message: 'Nome nao encontrado' });
      return;
    }

    const rows = await all('SELECT id, name, created_at AS createdAt FROM attendance WHERE id = ?', [id]);
    res.json(rows[0]);
  } catch (error) {
    res.status(500).json({ message: 'Erro ao atualizar frequencia', details: error.message });
  }
});

app.delete('/api/attendance/:id', async (req, res) => {
  const id = Number(req.params.id);

  try {
    const result = await run('DELETE FROM attendance WHERE id = ?', [id]);

    if (result.changes === 0) {
      res.status(404).json({ message: 'Nome nao encontrado' });
      return;
    }

    res.status(204).send();
  } catch (error) {
    res.status(500).json({ message: 'Erro ao excluir frequencia', details: error.message });
  }
});

app.get('/api/inventory', async (req, res) => {
  try {
    const rows = await all('SELECT id, name, quantity, created_at AS createdAt FROM inventory ORDER BY id DESC');
    res.json(rows);
  } catch (error) {
    res.status(500).json({ message: 'Erro ao carregar estoque', details: error.message });
  }
});

app.post('/api/inventory', async (req, res) => {
  const name = String(req.body.name || '').trim();
  const quantity = Number(req.body.quantity);

  if (!name || !Number.isInteger(quantity) || quantity < 0) {
    res.status(400).json({ message: 'Nome e quantidade inteira >= 0 sao obrigatorios' });
    return;
  }

  try {
    const result = await run('INSERT INTO inventory (name, quantity) VALUES (?, ?)', [name, quantity]);
    const rows = await all('SELECT id, name, quantity, created_at AS createdAt FROM inventory WHERE id = ?', [result.id]);
    res.status(201).json(rows[0]);
  } catch (error) {
    res.status(500).json({ message: 'Erro ao salvar item', details: error.message });
  }
});

app.put('/api/inventory/:id', async (req, res) => {
  const id = Number(req.params.id);
  const name = String(req.body.name || '').trim();
  const quantity = Number(req.body.quantity);

  if (!Number.isFinite(id) || !name || !Number.isInteger(quantity) || quantity < 0) {
    res.status(400).json({ message: 'Id, nome e quantidade inteira >= 0 sao obrigatorios' });
    return;
  }

  try {
    const result = await run('UPDATE inventory SET name = ?, quantity = ? WHERE id = ?', [name, quantity, id]);

    if (result.changes === 0) {
      res.status(404).json({ message: 'Item nao encontrado' });
      return;
    }

    const rows = await all('SELECT id, name, quantity, created_at AS createdAt FROM inventory WHERE id = ?', [id]);
    res.json(rows[0]);
  } catch (error) {
    res.status(500).json({ message: 'Erro ao atualizar item', details: error.message });
  }
});

app.delete('/api/inventory/:id', async (req, res) => {
  const id = Number(req.params.id);

  try {
    const result = await run('DELETE FROM inventory WHERE id = ?', [id]);

    if (result.changes === 0) {
      res.status(404).json({ message: 'Item nao encontrado' });
      return;
    }

    res.status(204).send();
  } catch (error) {
    res.status(500).json({ message: 'Erro ao excluir item', details: error.message });
  }
});

setup()
  .then(() => {
    app.listen(PORT, () => {
      console.log(`Servidor em http://localhost:${PORT}`);
    });
  })
  .catch((error) => {
    console.error('Falha na inicializacao:', error);
    process.exit(1);
  });

process.on('SIGINT', () => {
  db.close();
  process.exit(0);
});