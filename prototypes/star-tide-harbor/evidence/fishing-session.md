# Orion Blue Demo fishing observation

Environment: Steam original, window id 1444908 (OrionBlue.exe). Captures come directly from @oai/sky screenshots; extension matches MIME (image/jpeg).

## Confirmed first state

- Already in the fishing scene after a cast. Camera is underwater, with the waterline across the top of frame.
- A visible line descends from the top to the hook/bait near the middle of the screen. Two fish are visible to the left of the hook, at a distance.
- Upper-right HUD pairs two mouse-button glyphs with 收線 and 放線. The glyphs appear to indicate left-button reel and right-button release; active input behavior is being verified.
- No bite, fight meter, catch, break, bait loss, or placement state observed yet.

Evidence: [C:\Users\qazws\OneDrive\文件\ChatGPT\素材 draw\star-tide-harbor\evidence\orion-fishing-01-underwater.jpg](C:\Users\qazws\OneDrive\文件\ChatGPT\素材 draw\star-tide-harbor\evidence\orion-fishing-01-underwater.jpg)

## Fish engagement / fight HUD (cause not isolated)

A sky input attempt was interrupted by the runtime reporting user input in the same window. Following the required fresh observation, the game had changed to a fight state, so the action that triggered it is unconfirmed. The scene returned to a higher, near-surface view; a diagonal line runs from the upper-left edge toward the hooked fish near the surface. A centered horizontal colored meter (red/orange at left through yellow/green at right) contains a blue fish marker. The upper-right prompts now read 釣起魚 and 放生魚 beside two mouse-button glyphs. No numeric tension or stamina labels are visible in this frame, and no catch/failure settlement has appeared yet.

Evidence: [orion-fishing-02-bite-hud.jpg](orion-fishing-02-bite-hud.jpg)

## Returned to boat; bait stack reduced

After another runtime interruption from detected user input, a fresh capture showed the boat-side fishing state. The inventory bait stack now reads 10, compared with the 11 small caterpillars previously equipped. The HUD says S: 停止釣魚 and shows a mouse glyph with 抛竿. The rod is back in its idle casting pose and the line is no longer visibly extended. No explicit catch result card, fish name, reward, failure label, or line-break message is visible. Given overlapping user input, this capture only confirms the bait count changed to 10 and the scene returned; the outcome of the preceding fight remains unknown.

Evidence: [orion-fishing-03-return-boat-bait-count.jpg](orion-fishing-03-return-boat-bait-count.jpg)
