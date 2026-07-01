# ============================================================
#  🎨 FRONTEND — Streamlit
#  Run locally with:  streamlit run app.py --server.port 8501
# ============================================================

import os

import requests
import streamlit as st

# ── Base URL of our FastAPI backend ──────────────────────────
# Read from an environment variable so the same image works whether
# the backend is on localhost (running bare) or another container
# (e.g. http://backend:8000 when deployed by Ansible/Docker).
API_URL = os.getenv("API_URL", "http://localhost:8000")

# ── Page config ───────────────────────────────────────────────
st.set_page_config(
    page_title="Student API Explorer",
    page_icon="🎓",
    layout="wide",
)

# ── Title ─────────────────────────────────────────────────────
st.title("🎓 Student API Explorer")
st.markdown("Learn how **REST APIs** work by calling a live FastAPI backend!")
st.caption(f"Backend: `{API_URL}`")
st.divider()


# ── Helper: show request + response ───────────────────────────
def show_response(method: str, url: str, response):
    """Display the HTTP details in a clear way for students."""
    col1, col2 = st.columns(2)

    with col1:
        st.markdown("**📤 Request sent**")
        st.code(f"{method}  {url}", language="text")

    with col2:
        st.markdown(f"**📥 Response  |  Status: `{response.status_code}`**")
        color = "✅" if response.status_code < 400 else "❌"
        st.write(color)

    st.json(response.json())


# ── Sidebar navigation ────────────────────────────────────────
page = st.sidebar.radio(
    "Choose an API action",
    [
        "🏠 Home — Health Check",
        "📋 GET — All Students",
        "🔍 GET — One Student",
        "🔎 SEARCH — By Subject",
        "📊 GET — Stats",
        "➕ POST — Add Student",
        "✏️ PUT — Update Student",
        "🗑️ DELETE — Remove Student",
    ],
)

st.sidebar.divider()
st.sidebar.markdown("### 🧠 HTTP Methods")
st.sidebar.markdown("""
| Method | Purpose |
|--------|---------|
| `GET` | Read data |
| `POST` | Create data |
| `PUT` | Update data |
| `DELETE` | Remove data |
""")


# ════════════════════════════════════════════════════════════
#  PAGES
# ════════════════════════════════════════════════════════════

# ── 1. Health Check ──────────────────────────────────────────
if page == "🏠 Home — Health Check":
    st.header("Health Check")
    st.info("This is the simplest API call — it just asks the server 'are you alive?'")

    st.code(f"GET  {API_URL}/", language="text")

    if st.button("🚀 Send Request"):
        try:
            r = requests.get(f"{API_URL}/", timeout=10)
            show_response("GET", f"{API_URL}/", r)
        except Exception:
            st.error("❌ Could not reach the API. Is the backend running?")


# ── 2. Get All Students ───────────────────────────────────────
elif page == "📋 GET — All Students":
    st.header("Get All Students")
    st.info("Returns a list of **every student** stored in the database.")

    st.code(f"GET  {API_URL}/students", language="text")

    if st.button("🚀 Send Request"):
        r = requests.get(f"{API_URL}/students", timeout=10)
        show_response("GET", f"{API_URL}/students", r)

        if r.status_code == 200:
            import pandas as pd

            students = r.json()["students"]
            st.markdown("### 📊 As a Table")
            st.dataframe(pd.DataFrame(students), use_container_width=True)


# ── 3. Get One Student ────────────────────────────────────────
elif page == "🔍 GET — One Student":
    st.header("Get One Student by ID")
    st.info("Pass an **ID** in the URL — this is called a **path parameter**.")

    student_id = st.number_input("Student ID", min_value=1, value=1, step=1)
    url = f"{API_URL}/students/{student_id}"
    st.code(f"GET  {url}", language="text")

    if st.button("🚀 Send Request"):
        r = requests.get(url, timeout=10)
        show_response("GET", url, r)


# ── 4. Search by Subject ──────────────────────────────────────
elif page == "🔎 SEARCH — By Subject":
    st.header("Search Students by Subject")
    st.info("Uses a **query parameter** (`?subject=Math`) to filter results.")

    subject = st.selectbox("Subject", ["Math", "Science", "History"])
    url = f"{API_URL}/search?subject={subject}"
    st.code(f"GET  {url}", language="text")

    if st.button("🚀 Send Request"):
        r = requests.get(url, timeout=10)
        show_response("GET", url, r)


# ── 5. Stats ─────────────────────────────────────────────────
elif page == "📊 GET — Stats":
    st.header("Class Statistics")
    st.info("The API crunches the numbers and returns summary stats.")

    url = f"{API_URL}/stats"
    st.code(f"GET  {url}", language="text")

    if st.button("🚀 Send Request"):
        r = requests.get(url, timeout=10)
        show_response("GET", url, r)

        if r.status_code == 200:
            data = r.json()
            st.divider()
            c1, c2, c3, c4 = st.columns(4)
            c1.metric("👥 Total", data["total_students"])
            c2.metric("📈 Average", data["average_grade"])
            c3.metric("🏆 Highest", data["highest_grade"])
            c4.metric("📉 Lowest", data["lowest_grade"])


# ── 6. Add Student ────────────────────────────────────────────
elif page == "➕ POST — Add Student":
    st.header("Add a New Student")
    st.info("**POST** sends a **JSON body** to the server to create new data.")

    with st.form("add_form"):
        name = st.text_input("Name", value="Frank")
        grade = st.slider("Grade", 0, 100, 80)
        subject = st.selectbox("Subject", ["Math", "Science", "History"])
        submit = st.form_submit_button("🚀 Send POST Request")

    payload = {"name": name, "grade": grade, "subject": subject}
    st.markdown("**JSON body that will be sent:**")
    st.json(payload)

    if submit:
        r = requests.post(f"{API_URL}/students", json=payload, timeout=10)
        show_response("POST", f"{API_URL}/students", r)


# ── 7. Update Student ─────────────────────────────────────────
elif page == "✏️ PUT — Update Student":
    st.header("Update an Existing Student")
    st.info("**PUT** sends updated fields to the server. Only filled fields change.")

    with st.form("update_form"):
        student_id = st.number_input("Student ID to update", min_value=1, value=1, step=1)
        new_name = st.text_input("New name (leave blank to keep)")
        new_grade = st.number_input("New grade (0 = skip)", min_value=0, max_value=100, value=0)
        submit = st.form_submit_button("🚀 Send PUT Request")

    if submit:
        payload = {}
        if new_name:
            payload["name"] = new_name
        if new_grade:
            payload["grade"] = new_grade

        url = f"{API_URL}/students/{student_id}"
        r = requests.put(url, json=payload, timeout=10)
        show_response("PUT", url, r)


# ── 8. Delete Student ─────────────────────────────────────────
elif page == "🗑️ DELETE — Remove Student":
    st.header("Delete a Student")
    st.info("**DELETE** removes a resource permanently (from our in-memory DB).")

    student_id = st.number_input("Student ID to delete", min_value=1, value=1, step=1)
    url = f"{API_URL}/students/{student_id}"
    st.code(f"DELETE  {url}", language="text")

    st.warning("⚠️ This will remove the student from the database!")
    if st.button("🗑️ Send DELETE Request"):
        r = requests.delete(url, timeout=10)
        show_response("DELETE", url, r)
