# syncro-provider-noctalia
Search provider for SyncroMSP and Noctalia v5. Allows you to search through open tickets.

<img width="648" height="568" alt="image" src="https://github.com/user-attachments/assets/03ecaf75-ade7-4c63-85f5-f022b11ed273" />


*Disclaimer:* Fully vibe-coded. Made it for me, if someone else wants to use it, awesome. For that reason though, I'm not submitting it as a community plugin. 

### Usage:
Once added, enable the **Syncro Tickets** search provider plugin (`msp/syncro-tickets`) via Noctalia settings or the plugin manager.

You will need to generate an API key for your organization in the Syncro admin panel. Bare minimum it needs **List/Search** permissions for **Tickets** as well as **View Detail** for **Customers**. Once you have the key, paste it into the plugin settings. 

It's pretty much hardcoded to be set up how I like it. The provider searches through all open tickets from the last few weeks, regardless of assignment. Displays subject, status, and customer name.
