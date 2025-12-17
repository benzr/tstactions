## Test GitHub actions with docker

### Repo structure

project/
├── .github/
│   └── workflows/
│       └── check-execution.yml
├── docker/
│   ├── Dockerfile
│   └── entrypoint.sh
├── scripts/
│   └── run_check.py
├── check.py
├── index.html
├── results.db (generated)
└── generate_page.py

### Repo creation from scratch (not tested)
```bash
git init 
git add .
git commit -m "Initial setup"
git branch -M main
git remote add origin https://github.com/YOUR_USERNAME/YOUR_REPO.git
git push -u origin main
```

### Repo creation (after empty repo creation on GitHub and cloning)
```bash
git add .
git commit -m "Initial setup"
git push
```
