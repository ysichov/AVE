
<img width="1136" height="597" alt="image" src="https://github.com/user-attachments/assets/c513c8a9-a8c9-4421-a99d-f9e992fb8f46" />



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

  - Show Diff / Show just version file
  - 2-Pane view or Inline View
  - Don't show TOCS or let them be
  - Compact (only changes) or full version + changes
  - Remove the same version or let them be
  - Who is blame or doesn't matter )
  - User - user's last changed objects marked with green color
  - Date from which we want see versions

  
1. Program/Include or Functional module
<img width="1400" height="718" alt="image" src="https://github.com/user-attachments/assets/cf47ab03-9590-47b3-9d4b-712aed8800fe" />

By default it opens the difference between the latest version (base) and previous one in 2-pane mode.
The list don't include versions without changes - that is very comfortable thing. And we don't need to show ovjects list as it is only one.

If you press Toggle Button "2-pane" it will switch to  Inline mode.
<img width="1398" height="719" alt="image" src="https://github.com/user-attachments/assets/47df45cd-0a30-4888-a429-2fbeb23893d7" />

Double click on any version will show the difference between it and previous one.

If you want to compare any versions you need to click toggle button "Diff prev" - it will swithed to "Diff Any".
Choose version and press  button "Set Base'
<img width="1040" height="301" alt="image" src="https://github.com/user-attachments/assets/3c12fdd7-9e43-4633-9978-602dc7ce4e23" />
After changing we can go on double clicking on any other version to compare with Base version.

2. Class
   <img width="1623" height="714" alt="image" src="https://github.com/user-attachments/assets/652d9e6d-9a40-4910-bdc0-1babf365292c" />

It show all class includes: sections (Public, Protected, Private) + all methods.
So we can fast navigate for any part of the class.

4. TR/Task

  <img width="1621" height="637" alt="image" src="https://github.com/user-attachments/assets/d37ee942-9b01-42d0-98e7-3de00b42e454" />

It shows all TR/Tasks objects marking not existing objects by red color.

Double click on supported objects will show its code and versions list.

Double click on Class will switch to Class objects view (see point 2)

"Back" button will return from class objects list to TR/Task object list

5. Package
   <img width="1512" height="580" alt="image" src="https://github.com/user-attachments/assets/73716fad-4542-4231-b282-6c04e590d7f4" />


It shows all {ackage objects marking not existing objects by red color.

Double click on supported objects will show its code and versions list.

Double click on Class will switch to Class objects view (see point 2)

"Back" button will return from class objects list to TR/Task object list

And we can press toggle button 'Maximize view/StandardView" to hide tables and check only versions sources

<img width="1619" height="671" alt="image" src="https://github.com/user-attachments/assets/50a5591f-42f5-4863-8fcb-4508ec4f83aa" />

<img width="684" height="74" alt="image" src="https://github.com/user-attachments/assets/0b46ff1c-fbe5-4aac-960c-9e6b02298efa" />

This button will open this instruction in the browser )

And as a bonus HTML/JS local comparer ) - https://github.com/ysichov/Diff
<img width="1920" height="775" alt="image" src="https://github.com/user-attachments/assets/23816fe8-85e8-4291-82ac-32cd0392ce22" />




   
   
   
