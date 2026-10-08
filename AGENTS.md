# Low-data workflow for the FPS project

- Keep network data use low while working on this project.
- Do not read, attach, encode, or inspect an entire binary asset unless the current change requires that exact asset. This includes `.glb`, `.fbx`, `.blend`, textures, audio, archives, and `.godot/imported` files.
- Inspect binary assets through filenames, sizes, import metadata, and existing scene references first.
- Never recursively dump the project, Codex folders, generated imports, logs, or configuration into tool output. Search for exact filenames or text and cap output tightly.
- Reuse local assets. Do not download an asset again when a usable local copy already exists.
- Run focused headless tests first. Run the smallest test that verifies the changed system.
- For visual checks, capture only the relevant view. Prefer 1280x720 JPEG at moderate quality. Avoid repeated full-resolution PNG screenshots.
- View or send at most one representative preview per visual iteration unless another view is needed to diagnose a visible problem.
- Do not inspect `.godot`, backup folders, or unused asset packs unless the active issue specifically depends on them.
- Explain before any step likely to transfer more than 20 MB, and avoid it when a local or metadata-only check is sufficient.
