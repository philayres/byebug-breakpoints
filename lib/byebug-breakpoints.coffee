fs = require "fs"

# https://github.com/atom/decoration-example
# https://github.com/tomkadwill/atom-rails-debugger

ByebugBreakpointsView = require './byebug-breakpoints-view'
{CompositeDisposable} = require 'atom'

module.exports = ByebugBreakpoints =
  byebugBreakpointsView: null
  modalPanel: null
  subscriptions: null

  activate: (state) ->
    @decorationsByEditorId = {}

    # console.log 'ByebugBreakpoints activated'
    @byebugBreakpointsView = new ByebugBreakpointsView(
      state.byebugBreakpointsViewState)
    @modalPanel = atom.workspace.addModalPanel(
      item: @byebugBreakpointsView.getElement(), visible: false)

    # Events subscribed to in atom's system can be easily cleaned up with a
    #  CompositeDisposable
    @subscriptions = new CompositeDisposable

    # Register command that toggles this view
    # Not actually used
    @subscriptions.add atom.commands.add 'atom-workspace',
      'byebug-breakpoints:toggle': => @toggle()

    # without these, keystrokes do not seem to work
    @subscriptions.add atom.commands.add 'atom-workspace',
      'byebug-breakpoints:set': => @set()
    @subscriptions.add atom.commands.add 'atom-workspace',
      'byebug-breakpoints:clear': => @clear()
    @subscriptions.add atom.commands.add 'atom-workspace',
      'byebug-breakpoints:clear_all': => @clear_all()
    @subscriptions.add atom.commands.add 'atom-workspace',
      'byebug-breakpoints:clear_file': => @clear_editor()
    @subscriptions.add atom.commands.add 'atom-workspace',
      'byebug-breakpoints:toggle-breakpoint': => @toggle_breakpoint()

    # Highlight breakpoints when an editor is opened
    @subscriptions.add atom.workspace.observeActivePaneItem (item) =>
      @highlightExistingBreakpoints(item, 'line-number')

    # update breakpoints after saving an editor - some may have moved to
    # different lines
    @subscriptions.add atom.workspace.observeTextEditors (editor) =>
      @highlightExistingBreakpoints(editor, 'line-number')
      editor.onDidSave (path) =>
        @saveBreakpointsForBuffer(path)

  deactivate: ->
    @modalPanel.destroy()
    @subscriptions.dispose()
    @destroyAllDecorations()
    @byebugBreakpointsView.destroy()

  serialize: ->
    byebugBreakpointsViewState: @byebugBreakpointsView.serialize()

  toggle: ->
    # console.log 'ByebugBreakpoints was toggled!'

    if @modalPanel.isVisible()
      @modalPanel.hide()
    else
      @modalPanel.show()

  toggle_breakpoint: ->
    editor = atom.workspace.getActiveTextEditor()
    projectRoot = atom.project.getPaths()[0]
    row = editor.getCursorBufferPosition().row + 1
    path = editor.getPath()

    return if path.search(/\.rb/i) == -1
    breakpoint = "b #{path}:#{row}\n"

    fs.readFile "#{projectRoot}/.byebugrc", (err, data) =>
      if (err)
        throw err
      data = data.toString()
      if data.search(breakpoint) == -1
        # set
        data = data + breakpoint
        @setDecorationForCurrentSelection(editor, 'line-number', breakpoint)
      else
        # clear
        data = data.replace(new RegExp(breakpoint, 'g'), "")
        @clearDecorationForCurrentSelection(editor, 'line-number', breakpoint)

      fs.writeFile "#{projectRoot}/.byebugrc", data, (err) ->
        if (err)
          throw err


  set: ->
    # console.log 'set breakpoint'
    # add if not present
    editor = atom.workspace.getActiveTextEditor()
    projectRoot = atom.project.getPaths()[0]
    row = editor.getCursorBufferPosition().row + 1
    path = editor.getPath()

    # only for .rb files
    return if path.search(/\.rb/i) == -1
    breakpoint = "b #{path}:#{row}\n"

    fs.readFile "#{projectRoot}/.byebugrc", (err, data) ->
      if (err)
        throw err
      data = data.toString()
      return if data.search(breakpoint) != -1
      data = data + breakpoint
      fs.writeFile "#{projectRoot}/.byebugrc", data, (err) ->
        if (err)
          throw err

    @setDecorationForCurrentSelection(editor, 'line-number', "#{path}:#{row}")

  clear: ->
    # console.log 'clear breakpoint'
    # remove if found
    editor = atom.workspace.getActiveTextEditor()
    projectRoot = atom.project.getPaths()[0]
    row = editor.getCursorBufferPosition().row + 1
    path = editor.getPath()

    breakpoint = "b #{path}:#{row}\n"

    # only for .rb files
    return if path.search(/\.rb/gi) == -1
    fs.readFile "#{projectRoot}/.byebugrc", (err, data) ->
      if (err)
        throw err
      data = data.toString()
      return if data.search(breakpoint) == -1
      data = data.replace(new RegExp(breakpoint, 'g'), "")
      fs.writeFile "#{projectRoot}/.byebugrc", data, (err) ->
        if (err)
          throw err
    @clearDecorationForCurrentSelection(editor, 'line-number', "#{path}:#{row}")

  # Clear breakpoints in the given editor
  clear_editor: ->
    # console.log 'clear all'
    # remove if found
    editor = atom.workspace.getActiveTextEditor()
    projectRoot = atom.project.getPaths()[0]
    path = editor.getPath()
    breakpoint = "b #{path}:\\d+\\n"

    fs.readFile "#{projectRoot}/.byebugrc", (err, data) ->
      if (err)
        throw err
      data = data.toString()
      # exit if no breakpoints for file
      return if data.search(breakpoint) == -1
      # remove al breakpoints
      data = data.replace(new RegExp(breakpoint, 'g'), "")
      # write the updated file
      fs.writeFile "#{projectRoot}/.byebugrc", data, (err) ->
        if (err)
          throw err

    @destroyDecorationsForEditor(editor)

  # Clear breakpoints in all files
  clear_all: ->
    # console.log 'clear all'
    # remove if found
    editor = atom.workspace.getActiveTextEditor()
    projectRoot = atom.project.getPaths()[0]

    fs.readFile "#{projectRoot}/.byebugrc", (err, data) ->
      if (err)
        throw err
      data = data.toString()
      return if data.search(/\.rb:\d+/) == -1
      data = data.replace(/b.*\.rb:\d+\n/g, "")
      fs.writeFile "#{projectRoot}/.byebugrc", data, (err) ->
        if (err)
          throw err

    @destroyAllDecorations()

  ## Decoration API methods

  highlightExistingBreakpoints: (editor, type) ->
    # console.log 'Highlight Exising...'
    # @listMarkers('start highlight')
    editor = atom.workspace.getActiveTextEditor()
    return unless editor?
    projectRoot = atom.project.getPaths()[0]
    path = editor.getPath()
    return unless path?
    return if path.search(/\.rb/) == -1
    fs.readFile "#{projectRoot}/.byebugrc", (err, data) =>
      if (err)
        throw err
      data = data.toString()
      @destroyDecorationsForEditor editor
      for line in data.split('\n')
        if line.search(path) != -1
          row = line.match(/:(\d+)/)[1]
          row = Number(row-1)
          marker = editor.markBufferRange(
            [[row,1],[row,1]]
            )

          cached = @getCachedDecoration(editor, type, line)
          continue if cached? && cached != null
          decoration = editor.decorateMarker(marker,{
            type: type,
            class: "#{type}-red"})

          @setCachedDecoration(editor, type, decoration, line)
      atom.views.getView(atom.workspace).focus()
      # @listMarkers('end highlight')

  saveBreakpointsForBuffer: (savedPath) ->
    # only for .rb files
    return if savedPath.path.search(/\.rb/i) == -1

    editor = atom.workspace.getActiveTextEditor()
    projectRoot = atom.project.getPaths()[0]
    path = savedPath.path
    # read the file
    fs.readFile "#{projectRoot}/.byebugrc", (err, data) =>
      if (err)
        throw err
      # remove existing entries for path
      data = data.toString()
      r = new RegExp("^.*#{path}:\\d+\\n", 'mg')
      data = data.replace(r, '')
      # get the markers to update
      decs = @getCachedDecorations(editor)
      if decs?
        for dec in decs
          decoration = dec.dec
          marker = decoration.getMarker()
          # actual row
          row = marker.getHeadBufferPosition().row + 1
          # console.log "Marker row: #{row} was: #{dec.line}"
          data = data + "b #{path}:#{row}\n"
      # Save the changes
      fs.writeFile "#{projectRoot}/.byebugrc", data, (err) ->
        if (err)
          throw err

  ## Utility methods

  createDecorationFromCurrentSelection: (editor, type) ->
    # Get the user's selection from the editor
    range = editor.getSelectedBufferRange()

    # create a marker that never invalidates that folows the user's selection
    # range
    marker = editor.markBufferRange(range, invalidate: 'never')

    # create a decoration that follows the marker. A Decoration object is
    # returned which can be updated
    decoration = editor.decorateMarker(marker,
      {
        type: type,
        class: "#{type}-red"
      })

    decoration
  #
  # updateDecoration: (decoration, newDecorationParams) ->
  #   # This allows you to change the class on the decoration
  #   decoration.setProperties(newDecorationParams)

  destroyAllDecorations: ->
    for editor_id of @decorationsByEditorId
      decorations = @decorationsByEditorId[editor_id]
      for line in decorations
        decoration = line.dec
        @destroyDecorationMarker decoration
    @decorationsByEditorId = {}

  destroyDecorationsForEditor: (editor) ->
    # console.log 'Destroy decorations for editor'
    # decorations = @decorationsByEditorId[editor.id]
    decorations = @getCachedDecorations(editor)
    return unless decorations?
    for line in decorations
      decoration = line.dec
      @destroyDecorationMarker(decoration)
    delete @decorationsByEditorId[editor.id] # = []


  # Destory the decoration's marker because we will no longer need it.
  # This will destroy the decoration as well. Destroying the marker is the
  # recommended way to destory the decorations.
  destroyDecorationMarker: (decoration) ->
    # console.log "destroy marker #{decoration.getMarker()}"
    decoration.getMarker().destroy()
    # @listMarkers('destroy marker')

  setDecorationForCurrentSelection: (editor, type, line) ->
    # return unless editor = @getEditor()
    decoration = @getCachedDecoration(editor, type, line)
    unless decoration?
      decoration = @createDecorationFromCurrentSelection(editor, type)
      @setCachedDecoration(editor, type, decoration, line)
    atom.views.getView(atom.workspace).focus()
    decoration

  clearDecorationForCurrentSelection: (editor, type, line) ->
    decoration = @getCachedDecoration(editor, type, line)
    if decoration?
      @destroyDecorationMarker(decoration)
      @removeCachedDecoration(editor, line)
    atom.views.getView(atom.workspace).focus()
    decoration

  getEditor: () ->
    atom.workspace.getActiveTextEditor()

  removeCachedDecoration: (editor, line) ->
    @decorationsByEditorId[editor.id]?= []
    line_num = line.match(/:(\d+)/)[1]
    index = 0
    for i in @decorationsByEditorId[editor.id]
      if i.line == line_num
        @decorationsByEditorId[editor.id].splice(index, 1)
        return i.dec
      index += 1


  getCachedDecoration: (editor, type, line) ->
    # console.log "getCachedDecoration. Editor: #{editor.id} Line: #{line}"
    # console.log @decorationsByEditorId
    @decorationsByEditorId[editor.id]?= []
    # console.log @decorationsByEditorId[editor.id][line.match(/(\d+)/)[0]]
    # @decorationsByEditorId[editor.id][line.match(/(\d+)/)[0]]
    line_num = line.match(/:(\d+)/)[1]
    # for dec in @decorationsByEditorId[editor.id]
    #   next unless dec?
    #   next unless dec[line] == line
    #   return dec[type]
    for i in @decorationsByEditorId[editor.id]
      if i.line == line_num
        return i.dec


  getCachedDecorations: (editor) ->
    # console.log "getCachedDecorations"
    # console.log @decorationsByEditorId[editor.id]
    return unless editor
    
    @decorationsByEditorId[editor.id]

  setCachedDecoration: (editor, type, decoration, line) ->
    # console.log "setCachedDecoration #{editor.id} Line: #{line}"
    line_num = line.match(/:(\d+)/)[1]
    dec = {
      line: line_num
      dec: decoration }
    @decorationsByEditorId[editor.id]?= []
    # console.log @decorationsByEditorId
    @decorationsByEditorId[editor.id].push dec
    # console.log @decorationsByEditorId

  # listMarkers: (heading) ->
  #   editor=@getEditor()
  #   # console.log heading
  #   for marker in editor.findMarkers()
  #     console.log "#{marker}"
  #   console.log  "@decorationsByEditorId:"
  #   console.log @decorationsByEditorId
  #   console.log "@getCachedDecorations(editor)"
  #   console.log @getCachedDecorations(editor)
  #
  #   return unless @decorationsByEditorId[editor.id]?
  #   for cache in @decorationsByEditorId[editor.id]
  #     console.log  cache
