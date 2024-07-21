
# Kyoko <img src="https://github.com/xenanthropy/kyoko/assets/3527107/67ef2569-981e-4dcb-891b-4aea44f9089b" width="200" height="200">
<br>
Discord bot that selects a random image from Safebooru, either completely random or from a selection of tags



## Content
Focuses heavily on SFW content generation - enforces rating:safe, as well as excluding possible bad tags (barefoot, bikini, etc.)

## How to use
First, you can either:
* add the official bot to your server via [this link](https://discord.com/oauth2/authorize?client_id=1254484776564293743)<br>

or
* [Build from source](INSTALL.md) and run the bot locally (you will need to create a discord bot [HERE](https://discord.com/developers/applications) and plug its bot token into config.exs)<br>

or
* Download the [latest release here](https://github.com/xenanthropy/kyoko/releases) and run `./kyoko start` on linux/mac, `kyoko.bat start` for windows (the token is read from DISCORD_TOKEN environmental variable, run `export DISCORD_TOKEN=your_token_here` before running the command on linux/mac (and do the same for windows, whatever the command is..)

Once you have the bot added to your server through whatever means you chose: just run `/kyoko`! Tags are optional. Kyoko forces the use of `1girl` tag when no tag is specified (reduces the amount of posts the API has to retrieve) tags are separated by commas, spaces are replaced with underscores, i.e. `black_hair,blue_eyes,pink_bow`

Some tags are blocked as they may contain NSFW content (Safebooru doesn't allow graphic nudity but some nsfw content is present) the list of tags can be seen in the source code.
For a complete list of Safebooru tags, please [check here](https://safebooru.org/index.php?page=tags&s=list). If you wish to bypass the blocked tags, you may add `protocol_j` to your tag list which will allow you to bypass the block list (Note that bypassing the blocked tags list will make the resulting image ephemeral, to prevent people sending NSFW images in the server)

## F.A.Q.
__"I tried to get an image generated but it said there were no posts with those tags, but I know there are; What gives?"__<br>
Safebooru API can be flaky, please try to run the command again :)<br><br>

__"Where can I go to ask questions about the bot or for other assistance?"__<br>
I have an official [bot server here](https://discord.gg/3nXwVSmK) that you can join to ask questions! You're also free to try out the bot there as well if you'd like a live demo. Of course if you run into an actual bug, please make a github issue for it!<br><br>

__"I'm trying to search for a tag but it says i'm using a restricted tag, even though I checked and it's not on the list! What's happening?"__<br>
Due to the way i'm matching tags in the code, it matches for partial words too (i.e. if you use the tag "butterfly" and "butter" was banned, it would be a match) I am looking into ways to correct this issue, but in the meantime just attach `protocol_j` to your tag list to bypass the block please!
