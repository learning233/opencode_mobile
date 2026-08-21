# 📂 Adding Projects Guide

<p align="right">
  <b>English</b> | <a href="./新增项目.md">简体中文</a>
</p>

This guide explains how to add new local projects or import existing GitHub projects in OpenCode Mobile.

---

## 1. 🆕 Create a New Local Project

If you want to create a brand new local project from scratch:

1. **Create Project Directory**  
   Create a project folder manually, or use AI tools to generate the basic project structure.

2. **Initialize Git Repository**  
   Navigate to the project root directory and execute the following command to make an initial commit (required for tracking changes):
   ```bash
   git init && git add . && git commit -m "init"
   ```

3. **Add Project in App**  
   Open the **OpenCode Mobile** app, tap **Add Project**, and select the local project folder.

---

## 2. 🐙 Import an Existing GitHub Project

If you need to add a project that already exists on GitHub:

1. **Clone Project to Local Machine**  
   Use Git to clone the remote repository to your local machine:
   ```bash
   git clone <repository_url>
   ```

2. **Add Project in App**  
   Open the **OpenCode Mobile** app, tap **Add Project**, and select the cloned local project folder.
