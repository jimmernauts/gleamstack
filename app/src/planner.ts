import { enableDragDropTouch } from "@dragdroptouch/drag-drop-touch";

export function do_enable_drag_drop_touch() { 
    let rootel = document.querySelector("#active-week");
    console.log(rootel); 
    enableDragDropTouch();
}