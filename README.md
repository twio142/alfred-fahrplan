# Fahrplan

Deutsche Bahn connections from Alfred.

## Usage

`db` → pick origin → pick destination → `Return` to search departing now, `Cmd+Return` to set a time first.

### Setting a Time

| Input         | Meaning             |
| ------------- | ------------------- |
| `14:30`       | Depart at 14:30     |
| `+30m`        | In 30 minutes       |
| `+2h`         | In 2 hours          |
| `+1d`         | Tomorrow            |
| `25.03`       | March 25            |
| `25.03 14:30` | March 25 at 14:30   |

`Cmd+Return` to search by arrival instead of departure.

### Results

`Return` on a result → segment breakdown with platforms. `Return` on any segment copies the timetable to the clipboard.

**Mehr Verbindungen** at the bottom loads later connections. `Cmd+Return` for earlier, `Alt+Return` to re-search from now.

### Stops

`Shift+Return` on any stop to save/remove it. Saved stops appear at the top of the list.

`db.` reopens the last search instantly.

## Configuration

Alfred Preferences → Workflows → Fahrplan → **Configure Workflow**.

| Setting          | Default   | Description                                      |
| ---------------- | --------- | ------------------------------------------------ |
| **Keyword**      | `db`      | Trigger keyword                                  |
| **Home Address** | _(empty)_ | Address or station shown as "Home" in every list |

Requires a [Powerpack](https://www.alfredapp.com/powerpack/) licence.
