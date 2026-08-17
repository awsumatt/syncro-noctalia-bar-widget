# awsumatt/syncro-queue
Integrates your SyncroMSP ticket queue into your Noctalia v5 status bar.


<img width="602" height="479" alt="image" src="https://github.com/user-attachments/assets/7a6dc966-be98-46c0-abe3-85710739bfc5" />

*Disclaimer:* Fully vibe-coded. Made it for me, if someone else wants to use it, awesome. For that reason though, I'm not submitting it as a community plugin or creating an official plugin source. 

### Usage:

You will need to generate an API key for your organization in the Syncro admin panel. Bare minimum it needs **List/Search** permissions for **Tickets**. Once you have the key, paste it into the plugin settings. 

The panel will show 2 pages: tickets which are open and unassigned, and tickets which are open and assigned to a configured user. Syncro uses ID numbers on the backend to differentiate users. Easiest way to find your user ID is to click your name up in the top right and select **Profile/Password**. The number at the end of your **Personal Appointment Booking URL** is your user ID.

It's pretty much hardcoded to be set up how I like it. The indicator only tracks the Open & Unassigned queue and its panel page has **New** tickets at the top. The personal queue page has **Customer Reply** tickets at the top and our own custom **CSE Hold** status tickets at the bottom. Poke around in the code and you can pretty easily change some of that. 
