# ============================================================
#  🧪 UNIT TESTS — FastAPI backend
#
#  Run locally:
#    pip3 install -r requirements.txt -r requirements-dev.txt
#    pytest backend/ -v
#
#  Run in CI: the "Unit Tests (pytest)" Jenkins stage runs this
#  inside a throwaway python:3.11-slim container.
#
#  These tests use FastAPI's TestClient — no server or Docker
#  needed. Each test gets a fresh copy of the student database.
# ============================================================

import copy

from fastapi.testclient import TestClient
import main
import pytest

client = TestClient(main.app)


@pytest.fixture(autouse=True)
def fresh_database():
    """Snapshot the in-memory DB before each test and restore it after."""
    snapshot = copy.deepcopy(main.students_db)
    yield
    main.students_db.clear()
    main.students_db.extend(snapshot)


# ── Health check ─────────────────────────────────────────────
def test_health_check():
    response = client.get("/")
    assert response.status_code == 200
    assert response.json()["status"] == "OK"


# ── GET /students ────────────────────────────────────────────
def test_list_all_students():
    response = client.get("/students")
    body = response.json()
    assert response.status_code == 200
    assert body["total"] == 5
    assert body["students"][0]["name"] == "Alice"


# ── GET /students/{id} ───────────────────────────────────────
def test_get_one_student():
    response = client.get("/students/1")
    assert response.status_code == 200
    assert response.json()["name"] == "Alice"


def test_get_missing_student_returns_404():
    response = client.get("/students/999")
    assert response.status_code == 404
    assert response.json()["detail"] == "Student not found"


# ── POST /students ───────────────────────────────────────────
def test_create_student():
    payload = {"name": "Grace", "grade": 91, "subject": "Math"}
    response = client.post("/students", json=payload)
    assert response.status_code == 201
    created = response.json()["student"]
    assert created["id"] == 6
    assert created["name"] == "Grace"
    # The list should now contain 6 students
    assert client.get("/students").json()["total"] == 6


def test_create_student_rejects_bad_payload():
    # "grade" must be an integer — this should fail validation (422)
    response = client.post("/students", json={"name": "Bad", "grade": "not-a-number"})
    assert response.status_code == 422


# ── PUT /students/{id} ───────────────────────────────────────
def test_update_student_grade():
    response = client.put("/students/1", json={"grade": 97})
    assert response.status_code == 200
    assert response.json()["student"]["grade"] == 97


# ── DELETE /students/{id} ────────────────────────────────────
def test_delete_student():
    response = client.delete("/students/3")
    assert response.status_code == 200
    assert "Charlie" in response.json()["message"]
    assert client.get("/students/3").status_code == 404


# ── GET /search ──────────────────────────────────────────────
def test_search_by_subject_is_case_insensitive():
    response = client.get("/search", params={"subject": "math"})
    body = response.json()
    assert response.status_code == 200
    assert body["count"] == 2
    assert {s["name"] for s in body["students"]} == {"Alice", "Diana"}


# ── GET /stats ───────────────────────────────────────────────
def test_stats():
    response = client.get("/stats")
    body = response.json()
    assert response.status_code == 200
    assert body["total_students"] == 5
    assert body["average_grade"] == 79.8
    assert body["highest_grade"] == 95
    assert body["lowest_grade"] == 61


# ── GET /metrics (monitoring) ────────────────────────────────
def test_prometheus_metrics_exposed():
    response = client.get("/metrics")
    assert response.status_code == 200
    assert "http_request" in response.text
