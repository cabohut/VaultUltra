# Family Vault Ultra User Guide

## Getting Started
Family Vault Ultra keeps your family's important documents and information in one secure place. The first time you open it, six starter folders are created: **Legal, Financial, Medical, IDs, Property,** and **Personal**. Each comes with suggested items. Nothing is required, and you can skip anything that doesn't apply to you.

## Folders
- **Smart folders** (the original six) come with suggested items and ready-made fields.
- **Custom folders**: tap **+** on the Folders screen to create your own.
- **Suggested Items** appear at the top of a smart folder. Tap one to create it, or swipe left to skip it (you can restore it in Settings).
- **Reorder** folders with **Edit**, then drag them into place.
- **Delete a folder** by swiping left. You'll be asked to confirm. The folder and every item that is only in that folder (with its attachments) are permanently deleted. If the folder is shared, it is removed for everyone.

## Items
An item is one thing you're tracking, such as a bank account, a passport, or an insurance policy.
- Tap **+** inside a folder to create an item. Smart folders offer their own types. Other folders offer general types: Bank Account, Credit Card, Insurance Policy, and Account Login. You can also choose **Blank Item**.
- Choosing a type creates the item and opens it, with the right fields already set up.
- **Changed your mind?** If you go back from a new item before entering anything (no title, notes, field values, or attachments), it is discarded. A suggested item returns to the list.
- An item's **type** can't be changed after it's created. Create a new item if you need a different type.
- Items are grouped by type within each folder.
- Use **Notes** on any item for extra details.
- **Delete an item** by swiping left on it in the folder list and confirming. Its fields and attachments are deleted too. In a shared folder, the item is removed for everyone.

## Fields
- Tap a field's value to edit it. There's no separate edit screen.
- **Sensitive fields**, like account numbers and passwords, are masked. Tap the eye icon at the top of the item to show or hide them all.
- **Add Field** lets you choose a name, a type, and whether it's sensitive.
  - **Text** and **Number**: type a value.
  - **Currency**: type an amount.
  - **Date**: tap **Set Date**, then pick a date. Tap the **✕** to clear it.
- **Delete a field** by swiping left on it.

## Attachments
Each item can hold photos, scans, and files.
- **Add Photo**: attach a photo from your library.
- **Scan Document**: scan a paper document with your camera. Edges and perspective are corrected automatically. iOS asks for camera permission the first time.
- **Attach File**: import a PDF, image, or other file from Files or iCloud Drive.
- Tap an attachment to view it. Images open in a zoomable viewer. Other files open in a document viewer.
- Text in photos, scans, and imported images is recognized automatically so it can be searched.

## AI-Assisted Field Extraction
This is optional. Swipe left on an attachment that has recognized text and tap **Extract Info** to have key details suggested, such as a policy number from a scanned insurance card.
- It needs your own Anthropic API key, added in **Settings**.
- The recognized text from that document is sent to Anthropic to process it.
- You review the suggestions first. Nothing is saved until you choose which to keep. Matching existing fields are overwritten.

## Search
The **Search** tab looks across your whole vault:
- Item titles and notes
- Text recognized in scanned documents and photos
- Field values

**Sensitive fields are never searched or shown in results.**

## Sharing a Folder
Tap the person icon next to a folder to invite someone, such as a family member.
1. Add the people you want to invite and choose their permission.
2. Send them the invitation link by Messages or Mail, or copy the link and send it yourself.

- Adding someone does **not** notify them. They receive the invitation only when you send the link.
- They need Family Vault Ultra installed and must open the link while signed in to the Apple ID you invited.
- Only the people you invite can open the folder. With edit access, they can add and change items.
- The icon turns green once others have joined. Tap it to see who has access or to remove people.
- **If a folder is shared with you:** tap the link you were sent. The app opens and the folder appears in your Folders list.

## Security
- Face ID, Touch ID, or your device passcode is required every time you open the app. It locks again when you leave it.
- Your data is stored in your own private iCloud account and is encrypted. Family Vault Ultra has no servers and cannot see your data. Folders you share are visible to the people you invite.

## Settings
- **Help & About**: this guide.
- **Restore Suggested Items**: restore skipped suggestions and deleted smart folder. 
- **Anthropic API Key**: add or remove your key for AI-assisted extraction.
