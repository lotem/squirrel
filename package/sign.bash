appDir="build/Release/Squirrel.app"

allFiles=$(find "$appDir" -print)
for file in $allFiles; do
	if ! [[ -d "$file" ]]; then
		if [[ -x "$file" ]]; then
			echo "$file"
			codesign --force --options runtime --timestamp --sign "Developer ID Application: $1" "$file";
		fi;
	fi;
done;

codesign --force --options runtime --timestamp --sign "Developer ID Application: $1" "$appDir";

spctl -a -vv "$appDir";
