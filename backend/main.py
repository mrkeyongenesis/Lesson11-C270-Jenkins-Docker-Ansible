# ============================================================
#  📦 BACKEND — FastAPI
#  Run locally with:  uvicorn main:app --reload --port 8000
# ============================================================

from typing import Any

from fastapi import FastAPI, HTTPException
from pydantic import BaseModel

# ── 1. Create the app ────────────────────────────────────────
app = FastAPI(
    title="Student API",
    description="A simple API to learn REST concepts",
    version="1.0.0",
)

# ── 2. In-memory "database" (just a Python list) ─────────────
students_db: list[dict[str, Any]] = [
    {"id": 1, "name": "Alice", "grade": 88, "subject": "Math"},
    {"id": 2, "name": "Bob", "grade": 73, "subject": "Science"},
    {"id": 3, "name": "Charlie", "grade": 95, "subject": "History"},
    {"id": 4, "name": "Diana", "grade": 61, "subject": "Math"},
    {"id": 5, "name": "Eve", "grade": 82, "subject": "Science"},
]


# ── 4. Data model (what a student looks like) ─────────────────
class Student(BaseModel):
    name: str
    grade: int  # 0 – 100
    subject: str


class StudentUpdate(BaseModel):
    name: str | None = None
    grade: int | None = None
    subject: str | None = None


# ── 5. Helper ─────────────────────────────────────────────────
def find_student(student_id: int) -> dict[str, Any] | None:
    for s in students_db:
        if s["id"] == student_id:
            return s
    return None


# ============================================================
#  ROUTES  (each one = one API endpoint)
# ============================================================


# ── GET /  ── Health-check ────────────────────────────────────
@app.get("/")
def root():
    """Check that the API is running."""
    return {"message": "🎓 Student API is running!", "status": "OK"}


# ── GET /students  ── List all students ───────────────────────
@app.get("/students")
def get_all_students():
    """Return every student in the database."""
    return {"total": len(students_db), "students": students_db}


# ── GET /students/{id}  ── Get one student ────────────────────
@app.get("/students/{student_id}")
def get_student(student_id: int):
    """Return a single student by their ID."""
    student = find_student(student_id)
    if not student:
        raise HTTPException(status_code=404, detail="Student not found")
    return student


# ── POST /students  ── Add a new student ──────────────────────
@app.post("/students", status_code=201)
def create_student(student: Student):
    """Add a brand-new student to the database."""
    new_id = max(s["id"] for s in students_db) + 1
    new_student = {"id": new_id, **student.model_dump()}
    students_db.append(new_student)
    return {"message": "Student created!", "student": new_student}


# ── PUT /students/{id}  ── Update a student ───────────────────
@app.put("/students/{student_id}")
def update_student(student_id: int, updates: StudentUpdate):
    """Update one or more fields of an existing student."""
    student = find_student(student_id)
    if not student:
        raise HTTPException(status_code=404, detail="Student not found")
    for field, value in updates.model_dump(exclude_none=True).items():
        student[field] = value
    return {"message": "Student updated!", "student": student}


# ── DELETE /students/{id}  ── Remove a student ────────────────
@app.delete("/students/{student_id}")
def delete_student(student_id: int):
    """Remove a student from the database."""
    student = find_student(student_id)
    if not student:
        raise HTTPException(status_code=404, detail="Student not found")
    students_db.remove(student)
    return {"message": f"Student '{student['name']}' deleted!"}


# ── GET /search  ── Filter by subject ─────────────────────────
@app.get("/search")
def search_by_subject(subject: str):
    """Search students by subject name."""
    results = [s for s in students_db if s["subject"].lower() == subject.lower()]
    return {"subject": subject, "count": len(results), "students": results}


# ── GET /stats  ── Class statistics ───────────────────────────
@app.get("/stats")
def get_stats():
    """Return grade statistics for the whole class."""
    if not students_db:
        return {"message": "No students yet"}
    grades = [s["grade"] for s in students_db]
    return {
        "total_students": len(students_db),
        "average_grade": round(sum(grades) / len(grades), 1),
        "highest_grade": max(grades),
        "lowest_grade": min(grades),
    }
