# trustme

**trustme** is an addon that provides Trust summoning management in a single, centralized interface.

<p align="center">
  <img width="600px" style="max-width: 100%;" alt="image" src="https://github.com/user-attachments/assets/9a5b53b0-54c2-4859-83f1-b390b32866f5" />
  <img width="400px" style="max-width: 100%;" alt="image" src="https://github.com/user-attachments/assets/726fe786-0206-4e46-9119-198c7929d234" />
</p>

# Features

### Trust Profiles
- Create profiles to summon predefined sets of Trusts
- Summon an entire profile with a single command or click

### Trust Browser
- Browse your available Trusts
- Filter by:
  - Search terms
  - Category

### Collection & Progress Tracking
- Fetch current login campaign Trusts to see which ones you are missing
- Check which Trusts you do not own yet

### Trust Details & Wiki Integration
- View parsed data for a specific Trust from **bg-wiki.com** in a stylized in-game window
- Open related wiki pages directly from the same window

## Commands
`/trustme|tme|trusts|trust` Toggles the UI

`/trustme profile|p profilename` Summon trusts from a specified profile name

`/trustme trust|t Kupipi,Amchuchu,Sakura` Summon trusts from a sequence of trust name

`/trustme current|c` Summon trusts from the currently loaded profile

`/trustme load|l profilename` Load a profile using specified name

`/trustme logincampaign|lc` Fetch and compare current login campaign's trusts for sale to tell you which ones you are missing

`/trustme missing|m [optional: hideuc]` Returns which trusts you don't own yet, adding hideuc hides the UC trusts from the output

## Thanks & credits

- [ThornyFFXI](https://github.com/ThornyFFXI) for the function to get trusts (from [thotbar](https://github.com/ThornyFFXI/tHotBar))
