FasdUAS 1.101.10   ��   ��    k             l     ��������  ��  ��        l     �� 	 
��   	    Slife    
 �        S l i f e      l     ��������  ��  ��        l     ��  ��        Created by Edison Thomaz     �   4     C r e a t e d   b y   E d i s o n   T h o m a z      l     ��  ��    < 6  Copyright 2008 Slife Labs, LLC. All rights reserved.     �   l     C o p y r i g h t   2 0 0 8   S l i f e   L a b s ,   L L C .   A l l   r i g h t s   r e s e r v e d .      l     ��������  ��  ��        l     ��������  ��  ��        l    k ����  O     k     k    j ! !  " # " l   ��������  ��  ��   #  $ % $ l   �� & '��   & $  Initialize lists and messages    ' � ( ( <   I n i t i a l i z e   l i s t s   a n d   m e s s a g e s %  ) * ) r     + , + J    ����   , o      ���� 0 
resultlist 
resultList *  - . - l  	 	��������  ��  ��   .  / 0 / l  	 	�� 1 2��   1   Get the messages    2 � 3 3 "   G e t   t h e   m e s s a g e s 0  4 5 4 r   	  6 7 6 n   	  8 9 8 1    ��
�� 
smgs 9 4  	 �� :
�� 
mvwr : m    ����  7 o      ���� 0 themessages theMessages 5  ; < ; l   ��������  ��  ��   <  = > = l   �� ? @��   ? , & If there is only one message selected    @ � A A L   I f   t h e r e   i s   o n l y   o n e   m e s s a g e   s e l e c t e d >  B C B Z    b D E���� D =    F G F l    H���� H l    I���� I I   �� J��
�� .corecnte****       **** J o    ���� 0 themessages theMessages��  ��  ��  ��  ��   G m    ����  E k    ^ K K  L M L l   ��������  ��  ��   M  N O N l   �� P Q��   P   Repeat with all messages    Q � R R 2   R e p e a t   w i t h   a l l   m e s s a g e s O  S T S X    \ U�� V U k   , W W W  X Y X l  , ,��������  ��  ��   Y  Z [ Z l  , ,�� \ ]��   \ - ' Make sure that the message is not junk    ] � ^ ^ N   M a k e   s u r e   t h a t   t h e   m e s s a g e   i s   n o t   j u n k [  _ ` _ Z   , U a b���� a =  , 1 c d c n   , / e f e 1   - /��
�� 
isjk f o   , -���� 0 themsg theMsg d m   / 0��
�� boovfals b k   4 Q g g  h i h l  4 4��������  ��  ��   i  j k j l  4 4�� l m��   l 2 , Make the text item delimiters to be nothing    m � n n X   M a k e   t h e   t e x t   i t e m   d e l i m i t e r s   t o   b e   n o t h i n g k  o p o r   4 9 q r q m   4 5 s s � t t   r n      u v u 1   6 8��
�� 
txdl v 1   5 6��
�� 
ascr p  w x w l  : :��������  ��  ��   x  y z y l  : :�� { |��   { - ' Getting the sender and message content    | � } } N   G e t t i n g   t h e   s e n d e r   a n d   m e s s a g e   c o n t e n t z  ~  ~ r   : ? � � � n   : = � � � 1   ; =��
�� 
subj � o   : ;���� 0 themsg theMsg � o      ���� 0 
thesubject 
theSubject   � � � r   @ E � � � n   @ C � � � 1   A C��
�� 
sndr � o   @ A���� 0 themsg theMsg � o      ���� 0 	thesender 	theSender �  � � � l  F F��������  ��  ��   �  � � � l  F F�� � ���   � - ' Copy sender and subject to output list    � � � � N   C o p y   s e n d e r   a n d   s u b j e c t   t o   o u t p u t   l i s t �  � � � s   F J � � � o   F G���� 0 
thesubject 
theSubject � l      ����� � n       � � �  ;   H I � o   G H���� 0 
resultlist 
resultList��  ��   �  � � � s   K O � � � o   K L���� 0 	thesender 	theSender � l      ����� � n       � � �  ;   M N � o   L M���� 0 
resultlist 
resultList��  ��   �  ��� � l  P P��������  ��  ��  ��  ��  ��   `  ��� � l  V V��������  ��  ��  ��  �� 0 themsg theMsg V o     ���� 0 themessages theMessages T  ��� � l  ] ]��������  ��  ��  ��  ��  ��   C  � � � l  c c��������  ��  ��   �  � � � l  c c�� � ���   � %  Make the list the final result    � � � � >   M a k e   t h e   l i s t   t h e   f i n a l   r e s u l t �  � � � r   c h � � � o   c d���� 0 
resultlist 
resultList � 1      ��
�� 
rslt �  ��� � l  i i��������  ��  ��  ��     m      � ��                                                                                  emal   alis    D  Macintosh HD               ¡E�H+     Mail.app                                                         ���L�        ����  	                Applications    ¡}�      �M*`         "Macintosh HD:Applications:Mail.app    M a i l . a p p    M a c i n t o s h   H D  Applications/Mail.app   / ��  ��  ��     ��� � l     ��������  ��  ��  ��       �� � ���   � ��
�� .aevtoappnull  �   � **** � �� ����� � ���
�� .aevtoappnull  �   � **** � k     k � �  ����  ��  ��   � ���� 0 themsg theMsg �  �������������~�} s�|�{�z�y�x�w�v�� 0 
resultlist 
resultList
�� 
mvwr
�� 
smgs�� 0 themessages theMessages
�� .corecnte****       ****
� 
kocl
�~ 
cobj
�} 
isjk
�| 
ascr
�{ 
txdl
�z 
subj�y 0 
thesubject 
theSubject
�x 
sndr�w 0 	thesender 	theSender
�v 
rslt�� l� hjvE�O*�k/�,E�O�j k  G ?�[��l kh  ��,f  "���,FO��,E�O��,E�O��6GO��6GOPY hOP[OY��OPY hO�E` OPUascr  ��ޭ