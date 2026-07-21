# Example Python Website (Flask)

A minimal, runnable website built with [Flask](https://flask.palletsprojects.com/).
It demonstrates the three building blocks of nearly every Python web app.

## Run it

```bash
cd example_website
pip install -r requirements.txt
python app.py
```

Then open <http://127.0.0.1:5000> in your browser.

## What's inside

```
example_website/
├── app.py              # Python: routes (URL → function) and app startup
├── requirements.txt    # Dependencies (just Flask)
├── templates/          # HTML pages Python fills in with values
│   ├── base.html       # Shared layout (nav bar, footer) other pages extend
│   ├── index.html      # Home page  → "/"
│   ├── about.html      # About page → "/about"
│   └── greet.html      # A form that greets you → "/greet"
└── static/
    └── style.css       # Styling, served as-is to the browser
```

## How it works

1. **Routes** (`@app.route(...)` in `app.py`) connect a URL to a Python function.
2. **Templates** (`templates/*.html`) are HTML with `{{ placeholders }}` that
   Python fills in via `render_template(...)`.
3. **Static files** (`static/*`) — CSS, images, JS — are sent to the browser
   unchanged.

The `/greet` page also shows how to read data a user submits through a form.

## Next steps

- Add a database with **Flask-SQLAlchemy** to store data (e.g. a to-do list).
- Deploy it with a production server like **gunicorn** behind nginx, or on a
  host like Render, Railway, or Fly.io.
