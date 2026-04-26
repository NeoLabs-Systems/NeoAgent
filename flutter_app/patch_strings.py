import re

with open("android/app/src/main/res/values/strings.xml", "r") as f:
    content = f.read()

content = content.replace(
    "</resources>",
    '    <string name="widget_tasks_label">Tasks</string>\n    <string name="task_run_now">Run Now</string>\n</resources>'
)

with open("android/app/src/main/res/values/strings.xml", "w") as f:
    f.write(content)
