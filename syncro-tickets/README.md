# syncro-provider-noctalia
Search provider for SyncroMSP and Noctalia v5. Allows you to search through open tickets.



*Disclaimer:* Fully vibe-coded. Made it for me, if someone else wants to use it, awesome. For that reason though, I'm not submitting it as a community plugin or creating an official plugin source. 

### Installation:
Add this repository as a plugin source in Noctalia:
```bash
noctalia msg plugins source add syncro-msp git <your-repo-url>
```
Alternatively, clone this plugin source repository directly into your Noctalia plugins directory.

Once added, enable the **Syncro Tickets** search provider plugin (`msp/syncro-tickets`) via Noctalia settings or the plugin manager.

And that's it. It's installed. You will need to generate an API key for your organization in the Syncro admin panel. Bare minimum it needs **List/Search** permissions for **Tickets** as well as **View Detail** for **Customers**. Once you have the key, paste it into the plugin settings. 

It's pretty much hardcoded to be set up how I like it. The provider searches through all open tickets from the last few weeks, regardless of assignment. Displays subject, status, and customer name.
