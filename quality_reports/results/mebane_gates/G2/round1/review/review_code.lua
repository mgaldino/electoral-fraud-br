-- Allow wrapping of long paths in inline code without altering source text.
function Code(el)
  if FORMAT:match('latex') then
    local pieces = {}
    for first = 1, #el.text, 8 do
      table.insert(pieces, '\\detokenize{' .. el.text:sub(first, first + 7) .. '}')
    end
    return pandoc.RawInline('latex', '\\texttt{' .. table.concat(pieces, '\\allowbreak{}') .. '}')
  end
end
