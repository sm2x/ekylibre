((E, $) ->
  "use strict"

  #
  # AJAX error handler
  E.ajaxErrorHandler = (request, status, error) ->
    if console.error?
      console.error "AJAX failure (#{status}): #{error}"
    else
      alert("AJAX failure (#{status}): #{error}")
      console.log "AJAX failure (#{status}): #{error}"
    return true

  # This util method is used to simulate both
  # event.preventDefault() and event.stopPropagation().
  # It is used for compatibility issues as IE8 and below do
  # not handle event.preventDefault() or event.stopPropagation().
  E.stopEvent = (event) ->
    if !event
      event = window.event

    if !event
      return;

    if event.stopped == 'undefined'

      event.cancelBubble = true
      event.returnValue = false

      if event.stopPropagation
        event.stopPropagation()

      if event.stopImmediatePropagation
        event.stopImmediatePropagation()

      if event.preventDefault
        event.preventDefault()

  E.toggleValidateButton = (container) ->
    requiredFields = container.find('input[data-required]:visible')
    validateItemButton = container.find('button[data-validate]')
    requiredFields.each ->
      if $(this).val() ==''
        validateItemButton.attr("disabled",true)
        return false
      else
        validateItemButton.attr("disabled",null)
    requiredFields.each ->
      debugger
      element = $(this)
      element.on "selector:change", ->
        requiredFields.each ->
          debugger
          if $(this).val() ==''
            validateItemButton.attr("disabled",true)
            return false
          else
            validateItemButton.attr("disabled",null)
      element.change ->
        requiredFields.each ->
          if $(this).val() ==''
            validateItemButton.attr("disabled",true)
            return false
          else
            validateItemButton.attr("disabled",null)



) ekylibre, jQuery
