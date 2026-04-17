
<img width="1395" height="761" alt="image" src="https://github.com/user-attachments/assets/74e33170-9f0e-47b4-8de8-37e562d897ee" />

SAP ABAP Versions Explorer for SAP GUI.

First of all - Eclipse version is the best. 

But I want very fast interface for some cases:
- I don't want to see the list of all the same versions because of using TOC (Transport of copies)
- I DO WANT to see real objects owner especially when Transport of copies(TOC) used
- fast navigation within Transport Requests/Tasks
- fast navigation within methods inside a class
- fast navigation within objects inside a package
- defining not existant objects in the Transport Requests/Tasks

  So we can choose one of 5 object types, enter its name and press Enter

  <img width="690" height="538" alt="image" src="https://github.com/user-attachments/assets/f7a6e32d-405c-40be-bd66-6da1f6fc0668" />

  And we have predefined set of parameters which we can alter before run or after with the similar set of toogle buttons.

  -Show Diff / Show just version file
  - 2-Pane view or Inline View
  - Don't show TOCS or let them be
  - Compact (only changes) or full version + changes
  - Remove the same version or let them be
  - Who is blame or doesn't matter )
  - User - user's last changed objects marked with green color
  - Date from which we want see versions

  
1. Program/Include
<img width="1486" height="449" alt="image" src="https://github.com/user-attachments/assets/7c558837-33b0-44ed-a4fc-b16db34b6a34" />

By default it opens the difference between the latest version (base) and previous one in compact mode.
The list don't include versions without changes - that is very comfortable thing

If you press Button Inline it will switch to usual 2-Pane Mode
<img width="1880" height="452" alt="image" src="https://github.com/user-attachments/assets/cdf91f3f-57c6-48fa-ad7b-2e7bb3d1d974" />

Double click on any version will show the difference between base version and clicked one.
<img width="1625" height="550" alt="image" src="https://github.com/user-attachments/assets/9243bc30-48a9-40dd-9649-fd76d7af2f7e" />

For selecting other base version we should choose desired version and press button "Set Base'
<img width="1366" height="563" alt="image" src="https://github.com/user-attachments/assets/2e8bd8c6-0d2c-458c-8288-0b47effa5b6d" />
After changing we can go on double clicking on any other version to compare with Base version.

2. Class
   <img width="1432" height="536" alt="image" src="https://github.com/user-attachments/assets/0535973d-ab94-44b4-b00c-ed1b7798bc78" />
It show all class includes: sections (Public, Protected, Private) + all methods.
So we can fast navigate for any part of the class.

4. Function module - the same as programs but for FMs.

5. TR/Task

   <img width="1627" height="594" alt="image" src="https://github.com/user-attachments/assets/8a87c90b-bfe3-47bd-a8e1-d095b491b052" />
It shows all TR/Tasks objects marking not existing objects by red color.

Double click on supported objects will show its code and versions list.

Double click on Class will switch to Class objects view (see point 2)

"Back" button will return from class objects list to TR/Task object list


   
   
   
