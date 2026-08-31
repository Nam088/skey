#pragma once

#include <string_view>

namespace skey::windows {

class ITextHost {
public:
    virtual ~ITextHost() = default;
    virtual bool delete_previous(unsigned count) = 0;
    virtual bool insert_text(std::string_view utf8) = 0;
    virtual bool replace_selection(std::string_view utf8) = 0;
    virtual void commit() = 0;
    virtual void reset() = 0;
};

} // namespace skey::windows
