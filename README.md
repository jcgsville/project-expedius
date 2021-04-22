# Project Expedius

Building the same API in different stacks to explore the world of backend
software development in 2021.

This was inspired by a [twitter rant](https://twitter.com/jcgsville/status/1384339906722353153?s=20)
wherin I complained that API and infrastructure development is still too hard in
2021. At least, that's my theory. To test this theory, I'm going to build the the
same, relatively basic API in many different stacks.

I don't really know what I'm looking for. Maybe this is market research. Maybe
this is masochism 🤷‍♂️ (I use the shrug emoji too much 😬). Who knows how far I'll
make it with each set of tools.

If you want to follow along with commentary and any insights I've gained along
the way, I'll be posting them on [this long-lived thread](https://twitter.com/jcgsville/status/1384348242888986624?s=20).

## Requirements

I'm going to build a small API that models managing homework in a grade school
classroom. We'll have teachers, students, classes, homework submission and grading.

### Data Model

```gql
type User {
    name: String
    email: Email
}

type Teacher {
    user: User
    classes: ClassesConnection
}

type Student {
    user: User
    classes: ClassesConnection
}

type Class {
    teacher: Teacher
    students: StudentsConnection
    assignments: AssignmentsConnection
}

type Assignment {
    class: Class
    description: String
    dueAt: DateTime
    submissions: AssignmentSubmissionsConnection
}

enum SubmissionStatus {
    DRAFT
    SUBMITTED
    GRADED
}

type AssignmentSubmission {
    assignment: Assignment
    student: Student
    status: SubmissionStatus
    submittedAt: DateTime
    submissionContent: String
    feedback: AssignmentFeedback
}

type AssignmentFeedback {
    submission: AssignmentSubmission
    grade: Int
    feedbackContent: String
}
```

### Actions

The API needs to support the following actions

* Sign up as teacher or student
* Create a class
* Add a student to a class
* Create an assignment
* Create/edit a draft submission
* Finalize a submission
* Grade a submission

### Auth

We'll just do basic email/password authentication. No 2FA. No email verification.
No password reset. Though these are table stakes for many applications, I think
I can get a sense of what it would be like to build a real service without
actually implementing them.

The story for authentication is pretty simple: it's what you'd expect of a classroom.

* Teachers can see the students in their classes
* Students can see the students in their classes
* Teachers can create assignments in their class
* Students can create, edit, and finalize assignment submissions to assignments
  in their class
* Teachers can grade assignment submissions for assignments in their classrooms

### Aggregations

For each assignment, the API should expose the following data:

* Number of students who submitted on time, late, and not at all
* Min, max, and average grade

### Email notifications

A student should be emailed with a notification when an assignment is created
in one of their classes.

### Deployments, logging, monitoring

I may explore some different mechanisms for deploying the code as a part of this
project, but infrastructure is not the focus. Same goes for logging and monitoring.

The one part of infra that I'll be sure to explore for each tool, especially those
that lean heavily on configuration and less on code, is what the story is for
managing multiple environments in a CD pipeline. Even for the most nascent
of projects, this has been a big win in my experience. So, while it may seem
like overkill, I'm going to at least explore what the solution would look like.

### GraphQL and REST

I'm probably going to focus more on tools that enable you to build GraphQL APIs.
GraphQL has drastically accelerated frontend product velocity in my experience
building product. There's more of a burden on the API developer depending on the
tools used, but that's part of the point of this project: to discover what makes
that easier! BUT, I'm not ruling out all tools that build REST APIs quite yet.
Especially ones that do it for you!

### That's it

There are so many other really common use cases that I'd want to explore, but I'd
rather be broad than deep in my research for this project. Here are some other things
I'd ideally like to explicitly analyze for the future:

* Storing and serving versioned data
* Storing and serving time-series data
* Subscriptions / live updates
* More advanced aggregations that could power charts and graphs
* Replication to business analysis DB / tool
* Search!
