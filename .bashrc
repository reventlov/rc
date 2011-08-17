# make vital directories
mkdir -p ~/.r/tmp
mkdir -p ~/.r/bin
mkdir -p ~/.r/config


# shell nickname -- should happen early, because we may re-exec the shell
#
# This enables a project-based shell experience: each shell has a single
# currently-active project, with its own working directory stack, gvim session,
# etc.
function create_project_name() {
    if [ -f ~/.r/usr/share/dict/fake-nouns ]; then
        grep -Ev '[^a-z]' < ~/.r/usr/share/dict/fake-nouns \
            | head -n$$ | tail -n1
    elif [ -f /usr/share/dict/words ]; then
        grep -Ev '[^a-z]' < /usr/share/dict/words \
            | grep -Ev '.........' | grep -E '....' | head -n$$ | tail -n1
    else
        echo $$
    fi
}

function set_project() {
    if [ -n "$1" ]; then
        SHELL_NICK="$1"
    else
        SHELL_NICK="$(create_project_name)"
    fi
    echo "$SHELL_NICK" > ~/.r/config/last-project
    pwd > ~/.r/config/lwd."$SHELL_NICK"
    # Reload the shell to load the history
    HISTFILE=~/.r/config/history."$SHELL_NICK" \
        exec $(ps -o comm= $$ | sed -e 's/^-\([a-z0-9\/A-Z.-_]*\)/\1 -l /')
}

if [ -n "$SHELL_NICK" ]; then
    true # do nothing, we're apparently just re-sourcing .bashrc
elif [ -f ~/.r/config/last-project ]; then
    SHELL_NICK="$(cat ~/.r/config/last-project)"
else
    set_project
fi

if [ ~/.r/config/history."$SHELL_NICK" \!= "$HISTFILE" ]; then
    set_project "$SHELL_NICK"
fi


# set curl aliases first
if ! type -t curl-s >/dev/null; then
    if type -t curl >/dev/null; then
        alias curl-s="curl -s"
    elif type -t wget >/dev/null; then
        alias curl-s="wget -qO-"
    fi
fi

if ! type -t curl-st >/dev/null; then
    if type -t curl >/dev/null; then
        alias curl-st="curl -s --max-time"
    elif type -t wget >/dev/null; then
        alias curl-st="wget -qO- -T"
    fi
fi

# try to update, if possible
function update_dotfiles() {
    local DOTFILES=$(curl-s http://xn13.com/config/.dotfiles)
    for i in $DOTFILES; do
        echo "Retrieving $i..."
        if ! curl-s http://xn13.com/config/$i > ~/.r/tmp/$i; then
            echo "Failed; aborting"
            return 1
        fi
    done

    for i in $DOTFILES; do
        if [ -f ~/$i ]; then
            cp ~/$i ~/.r/tmp/$i.backup
        fi

        mv ~/.r/tmp/$i ~/$i
    done

    touch ~/.dotcheck

    exec $(ps -o comm= $$ | sed -e 's/^-/-l /')
}

if type -t curl-st >/dev/null; then
    if [ -z $(find ~/.dotcheck ! -mtime +1) ]; then
        if [ $(cat ~/.dotversion 2>/dev/null || echo 0) \
             -lt "$(curl-st 5 http://xn13.com/config/.dotversion \
                       || echo 0)" ]; then
            update_dotfiles
        fi

        touch ~/.dotcheck
    fi
fi

# shell opts
shopt -s checkwinsize
shopt -s histappend

function PREPEND_TO_PATH() {
    for i in "$@"; do
        if ! echo "$PATH" | grep -Fq "$i:"; then
            PATH=$i:$PATH
        fi
    done
}
function APPEND_TO_PATH() {
    for i in "$@"; do
        if ! echo "$PATH" | grep -Fq ":$i"; then
            PATH=$PATH:$i
        fi
    done
}
PREPEND_TO_PATH ~/.r/bin

# we like fancy completion -- when it works
if [ -f /etc/bash_completion ]; then
    if /bin/sh /etc/bash_completion 2>/dev/null >/dev/null; then
        source /etc/bash_completion
    else
        echo "bash_completion failed to load"
    fi
fi

# commands
# ll -- avoid confusing people who expect this
alias ll='_term_ls -l'

# 'gvim' opens a file in a new tab, or pops the file to the front.
real_gvim=$(which gvim)
function gvim() {
    $real_gvim --servername "$SHELL_NICK GVIM" \
        --remote-send "<Esc>:tablast<Enter>" 2> /dev/null
    $real_gvim --servername "$SHELL_NICK GVIM" \
        --remote-tab-silent "$@" 2>/dev/null
    wmctrl -R " $SHELL_NICK GVIM"
}

# end-gvims -- quit all open gvims
function end_gvims() {
    for i in $($real_gvim --serverlist); do
        $real_gvim --servername $i --remote-send '<ESC>:qa<Enter>'
    done
}

# isatty -- figures out if stdout is a tty
if ! type -t isatty >/dev/null; then
    if type -t cc >/dev/null; then
        echo '#include <unistd.h>
              int main() { return !isatty(1); }' > ~/.r/tmp/isatty.c
        cc -o ~/.r/bin/isatty ~/.r/tmp/isatty.c
    elif type -t perl >/dev/null; then
        function isatty() { perl -e 'use POSIX; exit !isatty(1);'; }
    elif type -t python >/dev/null; then
        function isatty() { python -c 'import os; exit(os.isatty(1))'; }
    elif type -t ruby >/dev/null; then
        function isatty() { ruby -e 'exit STDOUT.tty?'; }
    fi

    if ! type -t isatty >/dev/null; then
        alias isatty=false
    fi
fi

# ls_head -- used for ls inside cd(), below
if ! type -t ls_head >/dev/null; then
    if type -t cc > /dev/null; then
        sed -e 's/^  *//' >~/.r/tmp/ls_head.c <<'end_ls_head'
            #include <stdio.h>
            #include <stdlib.h>

            int main(int argc, char **argv)
            {
                long nLines = 10, nFound = 1, i = 0, j, c, bufLen = 0;
                size_t nRead;
                char *buf = NULL, *end;

                if (argc > 1)
                {
                    nLines = strtol(argv[1], &end, 10);
                    if (*end != '\0' || *argv[1] == '\0')
                    {
                        fprintf(stderr,
                                "Unable to parse %s as a number.\n",
                                argv[1]);
                        return EXIT_FAILURE;
                    }
                }

                while (nFound < nLines)
                {
                    c = getchar();
                    if (c == EOF)
                        return EXIT_SUCCESS;

                    putchar(c);
                    if (c == '\n')
                        ++nFound;
                }

                while ((c = getchar()) != EOF)
                {
                    if (i == bufLen)
                    {
                        bufLen += 160;
                        buf = realloc(buf, bufLen);
                        if (!buf)
                        {
                            fprintf(stderr,
                                    "Unable to allocate %ld bytes.\n",
                                    bufLen);
                            return EXIT_FAILURE;
                        }
                    }

                    buf[i++] = c;

                    if (c == '\n' && (c = getchar()) != EOF)
                    {
                        puts("...");
                        return EXIT_SUCCESS;
                    }
                }

                if ((j = fwrite(buf, 1, i, stdout)) != i)
                {
                    fprintf(stderr,
                            "Unable to write final %ld bytes.\n",
                            i - j);
                    return EXIT_FAILURE;
                }

                return EXIT_SUCCESS;
            }
end_ls_head
        cc -o ~/.r/bin/ls_head ~/.r/tmp/ls_head.c
    elif type -t perl >/dev/null; then
        function ls_head() {
            perl -e '$end = 10;
                     while (<>)
                     {
                         last if ++$i > $end;
                         print;
                     }
                     print if $i == $end;
                     print "...\n" if $i > $end;'
        }
    elif type -t sed >/dev/null; then
        function ls_head() { sed -e '11,$d;10c...'; }
    fi

    if ! type -t ls_head >/dev/null; then
        alias ls_head=head
    fi
fi

# md5sum
if (type -t md5 && ! type -t md5sum) >/dev/null; then
    alias md5sum=md5
fi

# _term_ls -- used by ls() and cd()
if ls -d --color=auto . 2>/dev/null >/dev/null; then # GNU ls
    function _term_ls() { command ls -F --color=always -w$COLUMNS "$@"; }
elif ls -d -G . 2>/dev/null >/dev/null; then # BSD ls
    function _term_ls() {
        CLICOLOR_FORCE=y LSCOLORS=Gxfxcxdxbxegedabagacad \
            command ls -GF -w$COLUMNS "$@"
    }
else
    function _term_ls() { command ls -F "$@"; }
fi

# ls -- with color and flags iff output is a terminal
function ls() {
    if isatty; then
        # Automatically "less" any single ls'ed regular file or symlink to a
        # regular file, if no options are passed to ls.  Suppress this by
        # passing -d to ls.
        if [ $# -eq 1 -a -f "$1" ]; then
            less "$@"
        else
            _term_ls "$@"
        fi
    else
        command ls "$@"
    fi
}

# grep -- with color iff supported and output is a terminal
if echo foo | grep --color=auto foo 2>/dev/null >/dev/null; then
    alias grep='grep --color=auto'
fi

# cd -- deep changes
#
# automatically ls | head when changing directory
# cd -E applies a regex to the current directory
# cd -p makes the directory before changing to it
# collapses multiple cd's in quick succession, for cd -
if [ "x$TERM" != "xdumb" ] && isatty; then
    if [ -f "~/.r/config/lwd.$SHELL_NICK" ]; then
        command cd "$(cat "~/.r/config/lwd.$SHELL_NICK")"
        OLDPWD="$PWD"
    fi

    function cd() {
        local cd_opts=
        local mkdir=false
        local pattern=
        local OLDOPTIND=$OPTIND
        OPTIND=1
        while getopts 'LPE:p' opt; do
            case "$opt" in
                L|P)
                    cd_opts=$cd_opts -$opt
                ;;

                E)
                    pattern=$OPTARG
                ;;

                p)
                    mkdir=true
                ;;
            esac
        done
        shift $(($OPTIND - 1))
        OPTIND=$OLDOPTIND

        if [ -n "$pattern" ]; then
            if type -t perl >/dev/null; then
                nwd=$(pwd | perl -pe "s$pattern;")
            elif type -t sed >/dev/null; then
                nwd=$(pwd | sed -e "s$pattern")
            else
                false
            fi

            if [ "$?" -ne 0 ]; then
                return
            fi
            echo "$nwd"
        elif [ -z "$1" ]; then
            nwd=~
        else
            nwd=$1
        fi

        if $mkdir; then
            mkdir -p -- "$nwd"
        fi

        # Don't update the OLDPWD when I change directories in
        # rapid succession... except when I use '-'.
        if [ -z "$_CANCEL_CD_CHAINING" ]; then
            if [ "x-" != "x$nwd" ]; then
                local CORRECTOLDPWD=$OLDPWD
            else
                # Reset this--after '-', next cd should reset
                # OLDPWD again.
                _CANCEL_CD_CHAINING=t
            fi
        else
            _CANCEL_CD_CHAINING=
        fi

        command cd $cd_opts -- "$nwd"

        if [ "$?" -eq 0 ]; then
            pwd > ~/.r/config/lwd."$SHELL_NICK"
        else
            if isatty; then _term_ls -dC "$@"* | ls_head; fi
        fi

        if [ -n "$CORRECTOLDPWD" ]; then
            OLDPWD=$CORRECTOLDPWD
        fi
    }
fi


# prompting
function _prompt() {
    if [ -n "$_EXEC_START_TIME" ]; then
        local PCT=$(($SECONDS - $_EXEC_START_TIME))

        if [ $PCT -lt 60 ]; then
            PROMPTELAPSED=
        elif [ $PCT -lt 3600 ]; then
            PROMPTELAPSED="$(printf '%dm%02ds elapsed' \
                                    $(($PCT / 60)) \
                                    $(($PCT % 60)))
"
        else
            PROMPTELAPSED="$(printf '%dh%02dm%02ds elapsed' \
                                    $(($PCT / 3600)) \
                                    $(($PCT / 60 % 60)) \
                                    $(($PCT % 60)))
"
        fi
        _EXEC_START_TIME=
    else
        PROMPTELAPSED=
    fi


    if [ "$COLUMNS" -gt 80 ]; then
        local pwdlen=$(($COLUMNS - 40 - $PROMPT_JUNK_LENGTH))
    else
        local pwdlen=$(($COLUMNS / 2 - $PROMPT_JUNK_LENGTH))
    fi

    PROMPTWD=$PWD

    if [ "$PROMPTWD" != "${PROMPTWD#$HOME}" ]; then
        PROMPTWD=~${PROMPTWD#$HOME}
    fi

    local i=${#PROMPTWD}
    local lastlen=0
    while [ ${#PROMPTWD} -gt $pwdlen -a ${#PROMPTWD} -ne $lastlen ]; do
        lastlen=${#PROMPTWD}
        PROMPTWD=$(echo $PROMPTWD | sed -e 's:/\([^/]\)[^/]\+/:/\1/:')
    done

    local title="$(pwd | sed -e 's:.*/::') ($PROMPT_HOST:$(pwd | \
                                                        sed -e 's:/[^/]*$::'))"
    # Set title, given right kind of terminal
    case $TERM in
        xterm*)
            echo -ne "\e]0;$title\007"
        ;;

        screen*)
            echo -ne "\ek$title\e\\"
        ;;
    esac

    if [ -n "$_LS_BEFORE_PROMPT" ]; then
        if isatty; then
            _term_ls -C | ls_head
        fi
        _LS_BEFORE_PROMPT=
    fi

    AT_PROMPT=t
}
PROMPT_COMMAND=_prompt

if [ -f ~/.r/etc/host-nick ]; then
    PROMPT_HOST=$(cat ~/.r/etc/host-nick)
else
    PROMPT_HOST=${HOSTNAME%%.*}
fi

# this is in a function to avoid leaking a bunch of variables
function _prompt_string() {
    local HASH=$(echo $PROMPT_HOST | md5sum | sed -e 's/ .*$//' | tr a-z A-Z)

    # Z=default color, N=shell_nick color, S=separator color
    local Z=""
    local N=""
    if   [ '33333333333333333333333333333333' \> "$HASH" ]; then Z=31; N=33
    elif [ '66666666666666666666666666666666' \> "$HASH" ]; then Z=32; N=35
    elif [ '99999999999999999999999999999999' \> "$HASH" ]; then Z=33; N=36
    elif [ 'CCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCC' \> "$HASH" ]; then Z=35; N=31
    else                                                         Z=36; N=32
    fi
    local S="$Z;1"


    case $TERM in
        # For xterms, try to use the full palette
        # But allow the fallback if 256-color palette isn't supported
        xterm*)
            Z="$Z;38;5;$(dc -e "16i $HASH 24* 2 80^ 1- / 7C+p")"
            N="$N;38;5;$(dc -e "16i $HASH 24* 2 80^ 1- / 8E+p")"
            S="$S;38;5;$(dc -e "16i $HASH 24* 2 80^ 1- / C4+p")"
        ;;
    esac

    local z='\[\e[0;'$Z'm\]'
    local s='\[\e[0;'$S'm\]'
    local n='\[\e[0;'$N'm\]'
    local w='\[\e[0m\]'
    local date='\D{%T}'
    PS1="$s\$PROMPTELAPSED$z$date$s|$n$SHELL_NICK$s|$z$PROMPT_HOST$s:$z"
    PS1="$PS1\$PROMPTWD$s>$w "
    PROMPT_JUNK_LENGTH=$((19 + ${#PROMPT_HOST} + ${#SHELL_NICK}))
}
_prompt_string
unset _prompt_string

# try to put the current command in the xterm/screen title
function _hook_exec() {
    if [ -n "$COMP_LINE" -o -z "$AT_PROMPT" ]; then
        return
    elif [ 0 -eq "$BASH_SUBSHELL" ]; then
        AT_PROMPT=''
    fi

    if [ _prompt = "$BASH_COMMAND" ]; then
        AT_PROMPT=''
        return
    fi

    _LS_BEFORE_PROMPT=

    local command=$(history 1 | sed -e 's/^ *[0-9]* *//');

    # Doing this in the foreground because, empirically, it's fast enough, and
    # doing it in the background results in a '[Done]' notification from the
    # shell before every command.
    sqlite3 ~/.r/config/history.db <<END_SQL 2>/dev/null >/dev/null
    CREATE TABLE IF NOT EXISTS history (command, time, project, cwd);
    ALTER TABLE history ADD COLUMN pid;
    INSERT INTO history VALUES ('$(echo "$command" | sed -e "s/'/''/g")',
                                $(date +%s),
                                '$(echo "$SHELL_NICK" | sed -e "s/'/''/g")',
                                '$(pwd | sed -e "s/'/''/g")',
                                $$);
END_SQL

    if isatty; then
        case $TERM in
            xterm*)
                echo -ne "\e]0;$command\007"
            ;;

            screen*)
                echo -ne "\ek$command\e\\"
            ;;
        esac

        # if we're using any command other than cd or ls, don't
        # collapse further cds for cd -
        if [ "ls " != "${command:0:3}" -a \
             "ls" != "$command" -a \
             "cd " != "${command:0:3}" -a \
             "cd" != "$command" ]; then
            _CANCEL_CD_CHAINING=t
        fi

        if [ "cd " = "${command:0:3}" -o "cd" = "$command" ]; then
            _LS_BEFORE_PROMPT=t
        fi
    fi

    _EXEC_START_TIME=$SECONDS
}

set -o functrace
shopt -s extdebug
trap _hook_exec DEBUG


# source any local overrides LAST
if [ -f ~/.bashrc.local ]; then source ~/.bashrc.local; fi
