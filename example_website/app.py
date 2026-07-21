"""A minimal Flask website.

Run it with:
    pip install -r requirements.txt
    python app.py

Then open http://127.0.0.1:5000 in your browser.
"""

from flask import Flask, render_template, request

# `app` is the core object Flask uses to route web requests to Python code.
app = Flask(__name__)


# A "route" maps a URL path to a Python function that returns the page.
@app.route("/")
def home():
    # render_template fills an HTML file (in templates/) with Python values.
    return render_template("index.html", title="Home")


@app.route("/about")
def about():
    return render_template("about.html", title="About")


# This route accepts form submissions (POST) as well as normal visits (GET).
@app.route("/greet", methods=["GET", "POST"])
def greet():
    name = None
    if request.method == "POST":
        # request.form holds the data the user typed into the form.
        name = request.form.get("name", "").strip() or "stranger"
    return render_template("greet.html", title="Greet", name=name)


if __name__ == "__main__":
    # debug=True auto-reloads on code changes and shows errors in the browser.
    app.run(debug=True)
