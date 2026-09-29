-- Break long paths and hashes in the PDF without changing the Markdown source.
function Code(el)
  if FORMAT:match('latex') then
    local chunks = {}
    for first = 1, #el.text, 8 do
      table.insert(chunks, '\\detokenize{' .. el.text:sub(first, first + 7) .. '}')
    end
    return pandoc.RawInline('latex', '\\texttt{' .. table.concat(chunks, '\\allowbreak{}') .. '}')
  end
end
