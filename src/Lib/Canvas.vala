/*
* Copyright (c) 2019 Alecaddd (http://alecaddd.com)
*
* This file is part of Akira.
*
* Akira is free software: you can redistribute it and/or modify
* it under the terms of the GNU General Public License as published by
* the Free Software Foundation, either version 3 of the License, or
* (at your option) any later version.

* Akira is distributed in the hope that it will be useful,
* but WITHOUT ANY WARRANTY; without even the implied warranty of
* MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
* GNU General Public License for more details.

* You should have received a copy of the GNU General Public License
* along with Akira.  If not, see <https://www.gnu.org/licenses/>.
*
* Authored by: Felipe Escoto <felescoto95@hotmail.com>
* Authored by: Alberto Fanjul <albertofanjul@gmail.com>
*/

public class Akira.Lib.Canvas : Goo.Canvas {
    private const int MIN_SIZE = 1;
    private const int MIN_POS = 10;

    /**
     * Signal triggered when item was clicked by the user
     */
    public signal void item_clicked (Goo.CanvasItem? item);

    /**
     * Signal triggered when item has finished moving by the user,
     * and a change of it's coordenates was made
     */
    public signal void item_moved (Goo.CanvasItem? item);

    public Goo.CanvasItem? selected_item;
    public Goo.CanvasRect select_effect;

     /*
        Grabber Pos:   8
                     0 1 2
                     7   3
                     6 5 4

        // -1 if no nub is grabbed
    */
    enum Nob {
        NONE=-1,
        TOP_LEFT,
        TOP_CENTER,
        TOP_RIGHT,
        RIGHT_CENTER,
        BOTTOM_RIGHT,
        BOTTOM_CENTER,
        BOTTOM_LEFT,
        LEFT_CENTER,
        ROTATE
    }

    private Goo.CanvasItemSimple[] nobs = new Goo.CanvasItemSimple[9];

    private weak Goo.CanvasItem? hovered_item;
    private Goo.CanvasRect? hover_effect;

    private bool holding;
    private double temp_event_x;
    private double temp_event_y;
    private double event_x_root;
    private double event_y_root;
    private double delta_x;
    private double delta_y;
    private double hover_x;
    private double hover_y;
    private double nob_size;
    private double current_scale;
    private int holding_id = Nob.NONE;
    private double bounds_x;
    private double bounds_y;
    private double bounds_w;
    private double bounds_h;

    construct {
        events |= Gdk.EventMask.BUTTON_PRESS_MASK;
        events |= Gdk.EventMask.BUTTON_RELEASE_MASK;
        events |= Gdk.EventMask.POINTER_MOTION_MASK;
        get_bounds (out bounds_x, out bounds_y, out bounds_w, out bounds_h);
    }

    public override bool button_press_event (Gdk.EventButton event) {
        remove_hover_effect ();

        current_scale = get_scale ();
        temp_event_x = event.x / current_scale;
        temp_event_y = event.y / current_scale;

        print("canvas temp event x: %f\n", temp_event_x);
        print("canvas temp event y: %f\n", temp_event_y);

        event_x_root = temp_event_x;
        event_y_root = temp_event_y;

        var clicked_item = get_item_at (event_x_root, event_y_root, true);

        if (clicked_item != null) {

            var clicked_id = get_grabbed_id (clicked_item);
            holding = true;

            if (clicked_id == Nob.NONE) { // Non-nub was clicked
                remove_select_effect ();
                add_select_effect (clicked_item);
                grab_focus (clicked_item);

                selected_item = clicked_item;
                holding_id = Nob.NONE;
            } else { // nub was clicked
                holding_id = clicked_id;
            }

        } else {
            remove_select_effect ();
            grab_focus (get_root_item ());
        }

        return true;
    }

    public override bool button_release_event (Gdk.EventButton event) {
        if (!holding) return false;

        holding = false;

        if (delta_x == 0 && delta_y == 0) {
            return false;
        }

        item_moved (selected_item);
        add_hover_effect (selected_item);

        delta_x = 0;
        delta_y = 0;


        return false;
    }

    public override bool motion_notify_event (Gdk.EventMotion event) {
        if (!holding) {
            motion_hover_event (event);
            return false;
        }
        var event_x = event.x / current_scale;
        var event_y = event.y / current_scale;

        print("event x: %f\n", event_x);
        print("event y: %f\n", event_y);

        print("temp event x: %f\n", temp_event_x);
        print("temp event y: %f\n", temp_event_y);

        delta_x = event_x - temp_event_x;
        delta_y = event_y - temp_event_y;

        print("delta x: %f\n", delta_x);
        print("delta y: %f\n", delta_y);

        double x, y, width, height;
        selected_item.get ("x", out x, "y", out y, "width", out width, "height", out height);

        print("x: %f\n", x);
        print("y: %f\n", y);

        var new_height = height;
        var new_width = width;

        var new_delta_x = delta_x;
        var new_delta_y = delta_y;

        print("new delta x: %f\n", new_delta_x);
        print("new delta y: %f\n", new_delta_y);

        print("height: %f\n", height);
        print("width: %f\n", width);

        bool update_x = new_delta_x != 0;
        bool update_y = new_delta_y != 0;

        print("update x: %s\n", update_x.to_string());
        print("update y: %s\n", update_y.to_string());

        switch (holding_id) {
            case Nob.NONE: // Moving
                selected_item.translate (fix_x_position (delta_x, width), fix_y_position (delta_y, height));
                break;
            case Nob.TOP_LEFT:
                selected_item.translate (new_delta_x, new_delta_y);
                new_width = fix_size (width - new_delta_x);
                new_height = fix_size (height - new_delta_y);
                break;
            case Nob.TOP_CENTER:
                new_height = fix_size (height - delta_y);
                if (new_delta_y == 0) {
                    new_height = height;
                    return false;
                }
                selected_item.translate (0, new_delta_y);
                break;
            case Nob.TOP_RIGHT:
                update_x = event_x > x;
                print("update x: %s\n", update_x.to_string());
                if (new_delta_x == 0)
                    if (delta_x > 0 && update_x) {
                        new_delta_x = delta_x;
                    }
                print("translate: %f,%f\n", 0, new_delta_y);
                selected_item.translate (0, new_delta_y);
                new_width = fix_size (width + new_delta_x);
                new_height = fix_size (height - new_delta_y);
                break;
            case Nob.RIGHT_CENTER:
                update_x = event_x > x;
                if (new_delta_x == 0)
                    if (delta_x > 0 && update_x) {
                        new_delta_x = delta_x;
                    } else
                        break;
                new_width = fix_size (width + new_delta_x);
                break;
            case Nob.BOTTOM_RIGHT:
                update_x = event_x > x;
                if (new_delta_x == 0)
                    if (delta_x > 0 && update_x) {
                        new_delta_x = delta_x;
                    }
                update_y = event_y > y;
                if (new_delta_y == 0)
                    if (delta_y > 0 && update_y) {
                        new_delta_y = delta_y;
                    }
                new_width = fix_size (width + new_delta_x);
                new_height = fix_size (height + new_delta_y);
                break;
            case Nob.BOTTOM_CENTER:
                update_y = event_y > y;
                if (new_delta_y == 0)
                    if (delta_y > 0 && update_y) {
                        new_delta_y = delta_y;
                    } else
                        break;
                new_height = fix_size (height + new_delta_y);
                break;
            case Nob.BOTTOM_LEFT:
                update_y = event_y > y;
                if (new_delta_y == 0)
                    if (delta_y > 0 && update_y) {
                        new_delta_y = delta_y;
                    } else
                        break;
                print("translate: %f,%f\n", new_delta_x, 0);
                selected_item.translate (new_delta_x, 0);
                new_width = fix_size (width - new_delta_x);
                new_height = fix_size (height + new_delta_y);
                break;
            case Nob.LEFT_CENTER:
                selected_item.translate (new_delta_x, 0);
                new_width = fix_size (width - new_delta_x);
                break;
            case Nob.ROTATE:
                var center_x = x + width / 2;
                var center_y = y + height / 2;

                print("center x: %f\n", center_x);
                print("center y: %f\n", center_y);

                var start_radians = GLib.Math.atan2 (center_y - temp_event_y, temp_event_x - center_x);
                print("start_radians %f, atan2(%f - %f, %f - %f)\n", start_radians, center_y, temp_event_y, temp_event_x, center_x);
                var radians = GLib.Math.atan2 (center_y - event_y, event_x - center_x);
                print("radians %f, atan2(%f - %f, %f - %f)\n", radians, center_y ,event_y, event_x, center_x);
                radians = start_radians - radians;
                var rotation = radians * (180 / Math.PI);
                print("rotation: %f\n", rotation);

                selected_item.rotate (rotation, center_x, center_y);
                break;
            default:
                break;
        }
        print("new width: %f\n", new_width);
        print("new height: %f\n", new_height);

        print("update x: %s\n", update_x.to_string());
        print("update y: %s\n", update_y.to_string());

        print("\n");

        selected_item.set ("width", new_width, "height", new_height);

        update_nob_position (selected_item);
        update_select_effect (selected_item);

        if (update_x) {
            temp_event_x = event_x;
            print("temp event x: %f\n", temp_event_x);
        }
        if (update_y) {
            temp_event_y = event_y;
            print("temp event y: %f\n", temp_event_y);
        }

        return true;
    }

    private void motion_hover_event (Gdk.EventMotion event) {
        hovered_item = get_item_at (event.x / get_scale (), event.y / get_scale (), true);

        if (!(hovered_item is Goo.CanvasItemSimple)) {
            remove_hover_effect ();
            return;
        }

        add_hover_effect (hovered_item);

        double check_x;
        double check_y;
        hovered_item.get ("x", out check_x, "y", out check_y);

        if ((hover_x != check_x || hover_y != check_y) && hover_effect != hovered_item) {
            remove_hover_effect ();
        }

        hover_x = check_x;
        hover_y = check_y;
    }

    private void add_select_effect (Goo.CanvasItem? target) {
        if (target == null || target == select_effect) {
            return;
        }

        double x, y;
        target.get ("x", out x, "y", out y);

        var item = (target as Goo.CanvasItemSimple);

        var line_width = 1.0 / current_scale;
        var stroke = item.line_width / 2;
        var real_x = x - stroke;
        var real_y = y - stroke;

        select_effect = new Goo.CanvasRect (null, real_x, real_y, 0, 0,
                                   "line-width", line_width,
                                   "stroke-color", "#666", null
                                   );

        update_select_effect (target);

        select_effect.set ("parent", get_root_item ());

        nob_size = 10 / current_scale;

        for (int i = 0; i < 9; i++) {
            var radius = i == 8 ? nob_size : 0;
            nobs[i] = new Goo.CanvasRect (null, 0, 0, nob_size, nob_size,
                "line-width", line_width,
                "radius-x", radius,
                "radius-y", radius,
                "stroke-color", "#41c9fd",
                "fill-color", "#fff", null
            );
            nobs[i].set ("parent", get_root_item ());
        }

        update_nob_position (target);
        select_effect.can_focus = false;
    }

    private void update_select_effect (Goo.CanvasItem? target) {
        if (target == null || target == select_effect) {
            return;
        }

        double width, height;
        target.get ("width", out width, "height", out height);

        var item = (target as Goo.CanvasItemSimple);
        var stroke = item.line_width / 2;
        var line_width = 1.0 / current_scale;
        var real_width = width + stroke * 2;
        var real_height = height + stroke * 2;

        select_effect.set ("width", real_width, "height", real_height);
        var transform = Cairo.Matrix.identity ();
        item.get_transform (out transform);
        select_effect.set_transform (transform);
    }

    private void remove_select_effect () {
        if (select_effect == null) {
            return;
        }

        select_effect.remove ();
        select_effect = null;
        selected_item = null;

        for (int i = 0; i < 9; i++) {
            nobs[i].remove ();
        }
    }

    public void reset_select () {
        if (selected_item == null && select_effect == null) {
            return;
        }

        select_effect.remove ();
        select_effect = null;

        for (int i = 0; i < 9; i++) {
            nobs[i].remove ();
        }

        current_scale = get_scale ();
        add_select_effect (selected_item);
    }

    private void add_hover_effect (Goo.CanvasItem? target) {
        if (target == null || hover_effect != null || target == selected_item || target == select_effect) {
            return;
        }

        if ((target as Goo.CanvasItemSimple) in nobs) {
            set_cursor_for_nob (get_grabbed_id (target));
            return;
        }

        double x, y, width, height;
        target.get ("x", out x, "y", out y, "width", out width, "height", out height);

        var item = (target as Goo.CanvasItemSimple);

        var line_width = get_scale () * 2;
        var stroke = item.line_width;
        var real_x = x - stroke;
        var real_y = y - stroke;
        var real_width = width + stroke * 2;
        var real_height = height + stroke * 2;

        hover_effect = new Goo.CanvasRect (null, real_x, real_y, real_width, real_height,
                                   "line-width", line_width,
                                   "stroke-color", "#41c9fd", null
                                   );
        var transform = Cairo.Matrix.identity ();
        item.get_transform (out transform);
        hover_effect.set_transform (transform);

        hover_effect.set ("parent", get_root_item ());


        hover_effect.can_focus = false;
    }

    private void remove_hover_effect () {
        set_cursor (Gdk.CursorType.ARROW);

        if (hover_effect == null) {
            return;
        }

        hover_effect.remove ();
        hover_effect = null;
    }

    private int get_grabbed_id (Goo.CanvasItem? target) {
        for (int i = 0; i < 9; i++) {
            if (target == nobs[i]) return i;
        }

        return Nob.NONE;
    }

    private void set_cursor_for_nob (int grabbed_id) {
        switch (grabbed_id) {
            case Nob.NONE:
                set_cursor (Gdk.CursorType.ARROW);
                break;
            case Nob.TOP_LEFT:
                set_cursor (Gdk.CursorType.TOP_LEFT_CORNER);
                break;
            case Nob.TOP_CENTER:
                set_cursor (Gdk.CursorType.TOP_SIDE);
                break;
            case Nob.TOP_RIGHT:
                set_cursor (Gdk.CursorType.TOP_RIGHT_CORNER);
                break;
            case Nob.RIGHT_CENTER:
                set_cursor (Gdk.CursorType.RIGHT_SIDE);
                break;
            case Nob.BOTTOM_RIGHT:
                set_cursor (Gdk.CursorType.BOTTOM_RIGHT_CORNER);
                break;
            case Nob.BOTTOM_CENTER:
                set_cursor (Gdk.CursorType.BOTTOM_SIDE);
                break;
            case Nob.BOTTOM_LEFT:
                set_cursor (Gdk.CursorType.BOTTOM_LEFT_CORNER);
                break;
            case Nob.LEFT_CENTER:
                set_cursor (Gdk.CursorType.LEFT_SIDE);
                break;
            case Nob.ROTATE:
                set_cursor (Gdk.CursorType.ICON);
                break;
        }
    }

    // Updates all the nub's position arround the selected item, except for the grabbed nub
    private void update_nob_position (Goo.CanvasItem target) {
        var item = (target as Goo.CanvasItemSimple);

        var stroke = (item.line_width / 2);
        double x, y, width, height;
        target.get ("x", out x, "y", out y, "width", out width, "height", out height);

        var middle = (nob_size / 2) + stroke;
        var middle_stroke = (nob_size / 2) - stroke;

        var transform = Cairo.Matrix.identity ();
        item.get_transform (out transform);

        // TOP LEFT nob
        nobs[Nob.TOP_LEFT].set_transform (transform);
        nobs[Nob.TOP_LEFT].translate (x - middle, y - middle);

        // TOP CENTER nob
        nobs[Nob.TOP_CENTER].set_transform (transform);
        nobs[Nob.TOP_CENTER].translate (x + (width / 2) - middle, y - middle);

        // TOP RIGHT nob
        nobs[Nob.TOP_RIGHT].set_transform (transform);
        nobs[Nob.TOP_RIGHT].translate (x + width - middle_stroke, y - middle);

        // RIGHT CENTER nob
        nobs[Nob.RIGHT_CENTER].set_transform (transform);
        nobs[Nob.RIGHT_CENTER].translate (x + width - middle_stroke, y + (height / 2) - middle);

        // BOTTOM RIGHT nob
        nobs[Nob.BOTTOM_RIGHT].set_transform (transform);
        nobs[Nob.BOTTOM_RIGHT].translate (x + width - middle_stroke, y + height - middle_stroke);

        // BOTTOM CENTER nob
        nobs[Nob.BOTTOM_CENTER].set_transform (transform);
        nobs[Nob.BOTTOM_CENTER].translate (x + (width / 2) - middle, y + height - middle_stroke);

        // BOTTOM LEFT nob
        nobs[Nob.BOTTOM_LEFT].set_transform (transform);
        nobs[Nob.BOTTOM_LEFT].translate (x - middle, y + height - middle_stroke);

        // LEFT CENTER nob
        nobs[Nob.LEFT_CENTER].set_transform (transform);
        nobs[Nob.LEFT_CENTER].translate (x - middle, y + (height / 2) - middle);

        // ROTATE nob
        double distance = 40;
        if (current_scale < 1) {
            distance = 40 + ((40 - (40 * current_scale)) * 2);
        }

        nobs[Nob.ROTATE].set_transform (transform);
        nobs[Nob.ROTATE].translate (x + (width / 2) - middle, y - (nob_size / 2) - distance);
    }

    private void set_cursor (Gdk.CursorType cursor_type) {
        var cursor = new Gdk.Cursor.for_display (Gdk.Display.get_default (), cursor_type);
        get_window ().set_cursor (cursor);
    }

    private double fix_y_position (double y, double height) {
        var min_delta = Math.round ((MIN_POS - height) * current_scale);
        var max_delta = Math.round ((bounds_h + height - MIN_POS) * current_scale);
        var new_y = Math.round (y);
        if (new_y < min_delta) {
            return min_delta;
        } else if (new_y > max_delta) {
            return max_delta;
        } else {
            return new_y;
        }
    }

    private double fix_x_position (double x, double width) {
        var min_delta = Math.round ((MIN_POS - width) * current_scale);
        var max_delta = Math.round ((bounds_h + width - MIN_POS) * current_scale);
        var new_x = Math.round (x);
        if (new_x < min_delta) {
            return min_delta;
        } else if (new_x > max_delta) {
            return max_delta;
        } else {
            return new_x;
        }
    }

    private double fix_size (double size) {
        var new_size = Math.round (size);
        return new_size > MIN_SIZE ? new_size : MIN_SIZE;
    }
}
