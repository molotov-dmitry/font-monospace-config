#!/bin/bash

set -e

TARGET='font-monospace-config'

#### Functions =================================================================

showmessage()
{
    local message="$1"

    if tty -s
    then
        echo "${message}"
        read -p "Press [Enter] to continue"
    else
        zenity --info --width 400 --text="${message}"
    fi
}

showquestion()
{
    local message="$1"

    if tty -s
    then
        while true
        do
            read -p "${message} [Y/n] " RESULT

            if [[ -z "${RESULT}" || "${RESULT,,}" == 'y' ]]
            then
                return 0
            fi

            if [[ "${RESULT,,}" == 'n' ]]
            then
                return 1
            fi
        done
    else
        if zenity --question --width 400 --text="${message}"
        then
            return 0
        else
            return 1
        fi
    fi
}

selectvalue()
{
    local title="$1"
    local prompt="$2"
    
    shift
    shift

    local result=''

    if tty -s
    then
        result=''
        
        echo "${prompt}" >&2
        select result in "$@"
        do
            if [[ -z "${REPLY}" ]] || [[ ${REPLY} -gt 0 && ${REPLY} -le $# ]]
            then
                break
            else
                
                continue
            fi
        done
    else
        while true
        do
            result=$(zenity --title="$title" --text="$prompt" --list --column="Options" "$@") || break
            if [[ -n "$result" ]]
            then
                break
            fi
        done
    fi
    
    echo "$result"
}

disableautostart()
{
    showmessage "Configuration completed. You can re-configure monospace font by running '${TARGET}' command"

    mkdir -p "${HOME}/.config/${TARGET}"
    echo "autostart=false" > "${HOME}/.config/${TARGET}/setup-done"
}

function ispkginstalled()
{
    app="$1"

    if dpkg -s "${app}" >/dev/null 2>&1
    then
        return 0
    else
        return 1
    fi
}

safestring()
{
    local inputstr="$1"

    echo "${inputstr}" | sed 's/\\/\\\\/g;s/\//\\\//g'
}

getconfigline()
{
    local key="$1"
    local section="$2"
    local file="$3"

    if [[ -r "$file" ]]
    then
        sed -n "/^[ \t]*\[$(safestring "${section}")\]/,/\[/s/^[ \t]*$(safestring "${key}")[ \t]*=[ \t]*//p" "${file}"
    fi
}

addconfigline()
{
    local key="$1"
    local value="$2"
    local section="$3"
    local file="$4"

    if ! grep -F "[${section}]" "$file" 1>/dev/null 2>/dev/null
    then
        mkdir -p "$(dirname "$file")"

        echo >> "$file"

        echo "[${section}]" >> "$file"
    fi

    sed -i "/^[[:space:]]*\[${section}\][[:space:]]*$/,/^[[:space:]]*\[.*/{/^[[:space:]]*$(safestring "${key}")[[:space:]]*=/d}" "$file"

    sed -i "/\[${section}\]/a $(safestring "${key}=${value}")" "$file"

    if [[ -n "$(tail -c1 "${file}")" ]]
    then
        echo >> "${file}"
    fi
}

backup()
{
    local file="$1"
    
    [[ -f "${file}" ]] && cp -f "${file}" "${file}.old"
}

restore()
{
    local file="$1"

    if [[ -f "${file}.old" ]]
    then
        mv "${file}.old" "${file}"
    else
        rm -f "${file}"
    fi
}

#### Globals ===================================================================

unset options
declare -a options

options=('Ubuntu Mono' 'Fira Code' 'JetBrains Mono' 'Noto Sans Mono' 'Hack')
sizes=('10' '12' '14' '16' '18')

#### Get system monospace fonts ================================================

# TODO

#### Sort and remove duplicates from fonts list ===============================

readarray -t fonts < <(for a in "${options[@]}"; do echo "$a"; done | uniq)

#### Select and apply font =====================================================

readonly schemagnome="org.gnome.desktop.interface monospace-font-name"
readonly filekde="${HOME}/.config/kdeglobals"
readonly schemabuilder="org.gnome.builder.editor font-name"
readonly fileqtcreator="${HOME}/.config/QtProject/QtCreator.ini"
readonly filekonsole="${HOME}/.local/share/konsole/UTF-8.profile"
readonly filekate="${HOME}/.config/kateschemarc"
readonly filesqlitebrowser="${HOME}/.config/sqlitebrowser/sqlitebrowser.conf"
readonly fileghostwriter="${HOME}/.config/ghostwriter/ghostwriter.conf"

### Apply settings =============================================================

while true
do
    newfont="$(selectvalue 'Monospace font' 'Please select font:' "${fonts[@]}")"
    
    if [[ -n "$newfont" ]]
    then
        newsize="$(selectvalue 'Font size' 'Please select size:' "${sizes[@]}")"
    fi
    
    newoptionskde="-1,5,50,0,0,0,0,0"
    newtypekde="Regular"
    
    if [[ -n "$newfont" && -n "$newsize" ]]
    then
    
        ## Gnome/Cinnamon ------------------------------------------------------
        
        if gsettings writable $schemagnome 1>/dev/null 2>/dev/null
        then
            oldfontgnome="$(gsettings get $schemagnome)"
            gsettings set $schemagnome "${newfont} ${newsize}"
        fi
        
        ## KDE -----------------------------------------------------------------
        
        if [[ -f "$filekde" ]]
        then
            backup "$filekde"
            
            addconfigline 'fixed' "${newfont},${newsize},${newoptionskde},${newtypekde}" 'General' "$filekde"
        fi
        
        ## Gnome Builder -------------------------------------------------------
        
        if gsettings writable $schemabuilder 1>/dev/null 2>/dev/null
        then
            oldfontbuilder="$(gsettings get $schemabuilder)"
            gsettings set $schemabuilder "${newfont} ${newsize}"
        fi
        
        ## Qt Creator ----------------------------------------------------------
        
        if ispkginstalled qtcreator
        then
            backup "$fileqtcreator"
            
            addconfigline 'FontFamily' "${newfont}" 'TextEditor' "$fileqtcreator"
            addconfigline 'FontSize'   "${newsize}" 'TextEditor' "$fileqtcreator"
        fi
        
        ## Konsole -------------------------------------------------------------
        
        if ispkginstalled konsole
        then
            backup "$filekonsole"
            
            addconfigline 'Font' "${newfont},${newsize},${newoptionskde},${newtypekde}" 'Appearance' "$filekonsole"
        fi
        
        ## Kate ----------------------------------------------------------------
        
        if ispkginstalled kate
        then
            backup "$filekate"
            
            addconfigline 'Font' "${newfont},${newsize},${newoptionskde},${newtypekde}" 'Normal' "$filekate"
        fi
        
        ## SQLite Browser ------------------------------------------------------
        
        if ispkginstalled sqlitebrowser
        then
            backup "$filesqlitebrowser"
            
            addconfigline 'font'     "${newfont}" 'editor'      "$filesqlitebrowser"
            addconfigline 'fontsize' "${newsize}" 'editor'      "$filesqlitebrowser"
            addconfigline 'font'     "${newfont}" 'databrowser' "$filesqlitebrowser"
        fi
        
        ## Ghostwriter ---------------------------------------------------------
        
        if ispkginstalled ghostwriter
        then
            backup "$fileghostwriter"
            
            addconfigline 'font' "${newfont},${newsize},${newoptionskde}" 'Style' "$fileghostwriter"
        fi
        
        ## ---------------------------------------------------------------------
        
        if showquestion "Save these settings?" "save" "try another"
        then
            break
        else
        
            ### Reset settings =================================================
            
            ## Gnome/Cinnamon --------------------------------------------------
            
            if gsettings writable $schemagnome 1>/dev/null 2>/dev/null
            then
                if [[ -n "${oldfontgnome}" ]]
                then
                    gsettings set $schemagnome "${oldfontgnome}"
                else
                    gsettings reset $schemagnome
                fi
            fi
            
            ## KDE -------------------------------------------------------------
            
            restore "$filekde"
            
            ## Gnome Builder ---------------------------------------------------
            
            if gsettings writable $schemabuilder 1>/dev/null 2>/dev/null
            then
                if [[ -n "${oldfontbuilder}" ]]
                then
                    gsettings set $schemabuilder "${oldfontbuilder}"
                else
                    gsettings reset $schemabuilder
                fi
            fi
            
            ## Qt Creator ------------------------------------------------------
            
            restore "$fileqtcreator"
            
            ## Konsole ---------------------------------------------------------
            
            restore "$filekonsole"
            
            ## Kate ------------------------------------------------------------
            
            restore "$filekate"
            
            ## SQLite Browser --------------------------------------------------
            
            restore "$filesqlitebrowser"
            
            ## Ghostwriter -----------------------------------------------------
            
            restore "$fileghostwriter"
            
            ## -----------------------------------------------------------------
            
            continue
        fi
    fi
    
    break

done

#### Disable autostart =========================================================

disableautostart
